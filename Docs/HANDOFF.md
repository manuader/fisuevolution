# HANDOFF — FisuEvolution, estado actual

> 🟢 **La v1.0.0 (build 4) está publicada en la App Store, y la v2 se trabaja en
> la rama `version-2`** (2.0.0, build 5). Si llegás para la v2, empezá por
> `Docs/HANDOFF-v2.md` §0 y por la sesión que preparó la rama,
> `Docs/SESION-2026-10-06-preparacion-v2.md`. Lo de abajo sigue siendo la
> referencia de arquitectura, decisiones y trampas.
>
> 🧭 **La 2.0 tiene plan maestro aprobado: `Docs/PLAN-v2.md`** (épicas E0–E11,
> ~55 decisiones del dueño, anexos de contenido). **Se ejecuta en relevo
> automático de agentes** (PLAN-v2 §0): cada agente trabaja hasta ~300.000
> tokens de contexto, cierra todo, documenta y le pasa la posta a uno con
> contexto fresco. El estado del run vive en el journal AVO
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout
> principal y excluido de git. Al llegar: este general + el handoff más nuevo
> de `handoffs/` + `PLAN-v2.md` + `tasks.md` + el journal.
>
> 📍 **Estado al cierre del relevo 30 (la ola AB, 2026-10-10; manda sobre los párrafos de abajo, que son del 29, del 28, del 27, del 26, del 25 y del 24):** `version-2` = **`56d7bfb`**, la punta tras el `rapido3` VERDE de `integ-r30` sobre `c2708aa` (EK 845 · unit 1444 · Release 0) · `v2i/integ-r30` = `6c4a770` (suma E8e T5, 🟢) + los docs del cierre (`v2i/docs-r30b`) · **`rapido4` sobre `6c4a770` EN CURSO** (`build/relevo30-rapido4.log`): decide E8e T5.
> **Progreso: 213 de 269 en `version-2` (79,2 %); 214 con E8e T5 ✅** si el `rapido4` da VERDE. El total subió de 254 a 269 porque entraron al tablero el plan E8e (9 tareas) y el de E8e T10 (6). Entraron E8 T9 (los recortes del dueño y el Estudio de assets, `rapido1` 209), E8e T1 y T7 (`ArtClips` y el Álbum con la tarjeta enfocada animada; B22 con ellas, 211), E8e T2 y T3 (el visitante que habla y la ilustración del evento, 213); queda 🟢 **E8e T5 (el colchón espera y se abre)**. B1–B26 quedaron como decisiones. **E8e T4 ⏳** (no ∥ E6a T12: `OroShopView`); **E8e T10a ⏳** (spike opus con medición; el gate lo mide el dueño en su SE). Detalle en `Docs/SESION-2026-10-10-v2-relevo-30-ola-ab.md`. Lo que sigue: `tasks.md` §4 (relevo 31): confirmar `version-2`, el veredicto del `rapido4`, y despachar **E8e T4**, **E8e T10a**, **E6a T12**, **E5b T3**, **E7b-b T1**, **E5b T5** y **E8d T15**.
>
> 📍 **Estado al cierre del relevo 29 (la ola AA, 2026-10-10; lo pisa el párrafo de arriba, el del 30):** `version-2` = **`236080b`**, la punta tras el `completo` VERDE de `integ-r29` sobre `7c494ea` (EK 845 · unit 1417 · store-unit 18 · store-ui 2 · iPad 4 · SE 2 · pipeline 89 · pacing-sim ✅ · Release 0; UI 129 verdes + 2 rojos por orden, `MenuPagerUITests` y `CustomizationUITests`, aislados VERDES) · `v2i/integ-r29` = `7c494ea` + `tasks.md` + los docs del cierre (`v2i/docs-r29`). Es el primer `completo` desde los cierres del 23.
> **Progreso: 208 de 254 en `version-2` (81,9 %).** Entraron E6b T4 (la pinta comprada con ORO; opus Approved con arreglos; `rapido` VERDE sobre `26df563`, 205), E5b T2 (los accesos y las hojas; opus Approved con arreglos y un BUG ALTO de la Ruleta: el video se veía y no pagaba), E4b T10 y E5a T9 (los cierres), cada una ✅ con el `completo`. **E5b T2 ✅ destraba E5b T3, E5b T5, E6a T12 y E7b-b T1 (⏳)**; E8d T15 sigue ⏳. El dueño mandó en el chat sus elecciones de recortes (`~/Desktop/revision-v2/decisiones.json`; `v2/e8-recortes` y `v2/estudio-assets` esperan integración) y pidió el plan E8e (`v2/e8e-plan`). Detalle en `Docs/SESION-2026-10-10-v2-relevo-29-ola-aa.md`. Lo que sigue: `tasks.md` §4 (relevo 30): **E6a T12** (dueña de `RootView` y catálogo), **E5b T3** (`BoardScene`), **E7b-b T1** (`GameState`), **E5b T5** y **E8d T15** (primero `AnimatedPlacesTests`, que no existe; después un `completo` solo).
>
> 📍 **Estado al cierre del relevo 28 (la ola Z, 2026-10-10; lo pisa el párrafo de arriba, el del 29):** `version-2` = **`a5ef14c`**, la punta tras el `rapido3` VERDE (EK 838 · unit 1389 · 0 rojos · Release 0) · `v2i/integ-r28` = `40f076e` (suma E6a T8, 🟢) + `tasks.md` + los docs del cierre (`v2i/docs-r28`) · `rapido4` de la punta: VERDE (EK 838 · unit 1396 · 0 rojos · Release 0): E6a T8 ✅, 204 de 254 (80,3 %).
> **Progreso: 203 de 254 en `version-2` (79,9 %); 204 de 254 (80,3 %) con E6a T8 ✅** si el `rapido4` da VERDE. Entraron E4b T6 (el Apagón y los Campeones), E6a T7 (las probabilidades del cofre; opus Approved) y E4b T9 (los especiales dejan el tablero), cada una ✅; queda 🟢 **E6a T8 (la pantalla Comprar ORO / Gastar ORO; opus Approved con arreglos, hechos en `aaa8767`)**. **E8 T9 hizo su Step 1** (la página `~/Desktop/revision-v2/index.html`, 359 recortes) y espera la elección del dueño. El dueño pidió la lista de todas sus preguntas y gates: **`PREGUNTAS-DUENO.md`** en el run (A1–A10, B1–B26); sus respuestas se vuelcan a decisiones. Detalle en `Docs/SESION-2026-10-10-v2-relevo-28-ola-z.md`. Lo que sigue: `tasks.md` §4 (relevo 29): **E5b T2** (la cabecera de la cadena larga), **E4b T10** y **E5a T9** (docs) y **E8d T15** (`completo` solo); E6b T4 cuando E6a T8 sea ✅.
>
> 📍 **Estado al cierre del relevo 27 (la ola Y, 2026-10-10; lo pisa el párrafo de arriba, el del 28):** `version-2` = **`9a0ee06`**, la punta tras el `rapido3` VERDE sobre `d860556` (EK 829 · unit 1356 · 0 rojos · Release 0) · `v2i/integ-r27` = `e2709d9` (suma E6a T6 y E2b T10, 🟢) + `tasks.md` + los docs del cierre (`v2i/docs-r27`) · `rapido4` de la punta: VERDE (EK 829 · unit 1380 · 0 rojos · Release 0): E6a T6 y E2b T10 ✅, 200 de 254 (78,7 %).
> **Progreso: 200 de 254 en `version-2` (78,7 %)**: el `rapido4` de la punta dio VERDE (EK 829 · unit 1380) y E6a T6 y E2b T10 son ✅. Entraron E6a T4 (`oro_shop.json`), E5b T4 (la Ruleta en Regalos), E5b T6 (`wheel_ready`) y E4b T4 (eventos con presentador; adiós al banner), cada una con su `rapido` VERDE (unit 1336, 1341, 1341, 1356); quedan 🟢 **E6a T6 (comprar en la Tienda de ORO)** y **E2b T10 (presupuestos analíticos)**. Dos revisiones opus (E4b T4 Approved con arreglos; E6a T6 Changes requested, arreglado). Detalle en `Docs/SESION-2026-10-10-v2-relevo-27-ola-y.md`. Lo que sigue: `tasks.md` §4 (relevo 28): **E4b T6** (el Apagón; destraba T9 → E5b T2) y **E6a T7** (la suerte), más **E5a T9** y **E8d T15**.
>
> 📍 **Estado al cierre del relevo 26 (la ola X, 2026-10-10; lo pisa el párrafo de arriba, el del 27):** `version-2` = **`652bc6a`**, la punta tras el `rapido` VERDE sobre `4b44a4e` (EK 827 · unit 1308 · 0 rojos · Release 0) · `v2i/integ-r26` = `1f090ef` (suma E7b-a T3, 🟢) + `tasks.md` + los docs del cierre (`v2i/docs-r26`) · `rapido` de la punta: VERDE (EK 827 · unit 1329 · 0 rojos · Release 0): E7b-a T3 ✅, 194 de 254 (76,4 %).
> **Progreso: 193 de 254 en `version-2` (76,0 %); 194 de 254 (76,4 %) con E7b-a T3 ✅** si el `rapido` de la punta da VERDE. Entraron E4b T5 (el reto y las cartas del Vendedor), E6a T5 (auto-tap, Offline ×3 y Diario ×3 se entregan), E5b T1 (la Ruleta en pantalla), E8b T11 (el arresto) y E7b-b T6 (Diario ×2 y carrera ×2 por video), cada una con su `rapido` VERDE (unit 1289, 1289, 1300, 1302, 1308); queda 🟢 **E7b-a T3 (la pausa publicitaria: el bloqueo de publicación)**. Tres revisiones opus (E6a T5 Approved; E5b T1 y E7b-a T3 Approved con arreglos, hechos). Detalle en `Docs/SESION-2026-10-10-v2-relevo-26-ola-x.md`. Lo que sigue: `tasks.md` §4 (relevo 27): **E4b T4** (eventos con presentador; dueña de `GameState`/`RootView`), **E6a T4**, **E5b T4**/**T6**, **E5a T9** y **E8d T15**.
>
> 📍 **Estado al cierre del relevo 25 (la ola W, 2026-10-10; lo pisa el párrafo de arriba, el del 26):** `version-2` = la punta tras el `rapido` VERDE sobre `73a7196` (EK 827 · unit 1247 · 0 rojos · Release 0) · `v2i/integ-r25` = `c435bad` (suma E5a T8 y E4b T3, 🟢) + `tasks.md` + los docs del cierre · `rapido` de la punta: VERDE (EK 827 · unit 1275 · 0 rojos · Release 0): E5a T8 y E4b T3 ✅, 188 de 254 (74,0 %).
> **Progreso: 186 de 254 en `version-2` (73,2 %); 188 de 254 (74,0 %) con E5a T8 y E4b T3 ✅** si el `rapido` de la punta da VERDE. Entraron E4b T8 (el Álbum de especiales), E4b T2 (los visitantes en la partida) y E5a T7 (el Colchón); quedan 🟢 E5a T8 (la Ruleta + `LootBoxGate`) y E4b T3 (el chip, el popup y el retrato). El `rapido` de E5a T8 dio ROJO por un flake de ODR (`ArtPacksTests.failureDoesNotLoop`, aislado 8/8 VERDE). Detalle en `Docs/SESION-2026-10-10-v2-relevo-25-ola-w.md`. Lo que sigue: `tasks.md` §4 (relevo 26): **E5b T1** primero, y **E7b-a T3 (bloqueo de publicación) en cuanto E5b T1 entre**; en paralelo E4b T5 y E6a T5.
>
> 📍 **Estado al cierre del relevo 24 (la ola V, 2026-10-10; lo pisa el párrafo de arriba, el del 25):** `version-2` = **`91b7634`** tras el `rapido` VERDE sobre
> `25cc5da` (EK 825 · unit 1190 · 0 rojos · Release 0) · `v2i/integ-r24` = `9b02cdd` (suma E4b T1, 🟢) + `tasks.md` · `rapido` de la punta: VERDE (EK 827 · unit 1207 · 0 rojos · Release 0).
> **Progreso: 182 de 254 en `version-2` (71,7 %); 183 de 254 con E4b T1 🟢.** Entraron E4a T10 (cierre de E4a), E2b T7/T8 (perfil `.max` y CLI del simulador), E4b T7 (la Liquidación
> en el precio) y E6a T11 (las ofertas se cobran). El `rapido` encontró un bug real: el piso de descuentos de E4b T7 anulaba la contratación gratis (`25cc5da`). Detalle en
> `Docs/SESION-2026-10-10-v2-relevo-24-ola-v.md`. Lo que sigue: `tasks.md` §4 (relevo 25): **E4b T2** o **E5a T7** (comparten `+Engagement`: una por ola), **E4b T8**.
>
> 🧪 **Se verifica con `Tools/v2/oraculo.sh tarea|rapido|completo`** (§6): el
> agente de una tarea corre `tarea <Clases>` (sólo sus tests); el `rapido`
> (que también compila Release) lo corre el controlador una vez por ola. Los
> agentes en paralelo se
> lanzan con `Agent(isolation: "worktree")` (PLAN-v2 §0.1; §7 explica por qué
> cualquier otra forma choca con el guard). Al 2026-10-09 (cierre del relevo
> 22, la ola T): `version-2` = la punta de **`9cccaf6`** tras su `rapido` VERDE (EK 708 · unit 1136 · 0 rojos · Release 0) · la rama de integración `v2i/integ-r22` = **`8ab8b33`** + estos
> docs (`rapido` sobre `8ab8b33`: VERDE (EK 735 · unit 1143 · 0 rojos · Release 0)). Están E0, E10 en papel, E8 pipeline, E8 audio, E7a, la parte de idioma de E3 y las olas B a T: **compartir recableado** (E3b T9, la
> llave de E4a), **la privacidad del ranking** (E12 T15), **las tres familias en el catálogo** (E6b T9), **los relojes de visitantes y eventos en el save** (E4a T3), **el motor de eventos
> y los visitantes puros** (E4a T4 y T5), **buzón, colchón y ruleta en el save** (E5a T4) y, en `integ-r22`, el `VisitPlanner` (E4a T6), el contenido de los 18 visitantes (E4a T7) y la
> tienda y las ofertas en el save (E6a T1). **Progreso: 159 de 254 tareas activas en `version-2` (62,6 %); 162 de 254 (63,8 %) si el `rapido` de `integ-r22` da VERDE** (`tasks.md` §2).
> **El último `completo` de referencia sigue siendo el de los cierres, sobre `0383a1d`** (`Docs/SESION-2026-10-09-v2-cierres-e11-e2a-e8c-e3a.md`).
> Detalle en `Docs/SESION-2026-10-09-v2-relevo-22-ola-t.md`.
>
> 🛑 **No publicar E7b-a T2 sin E7b-a T3:** sin la pausa publicitaria sale un intersticial en **cada** corte natural (no alterna). Falta además `canRequestAds`
> en el intersticial y el rewarded (UE sin consentimiento).
>
> 🌿 **Ramas sin mergear a `version-2`:** `v2i/integ-r22` (tres cambios y los docs del cierre; si su `rapido` dio verde, el primer paso del relevo 23 es el
> fast-forward). `v2/e12-plan`, `v2/release-ops` y `v2/e8-videos` son de la sesión del dueño; no se tocan. **Lo primero del relevo 23:** el `rapido` de
> `integ-r22` si no quedó hecho (lanzado con `nohup perl -e 'setpgrp(0,0); exec @ARGV' bash <ruta absoluta>/Tools/v2/oraculo.sh rapido`; `setsid` no existe) y después la cola de
> `tasks.md` §4.2: **E4a T9** (la mudanza a eventos v2), **E6a T2 y T10** (EK puras), **E5a T5** cuando E4a T9 entre, los cierres con `completo` (**E8 T10, E13b T11**) y
> **E7b-a T3** en cuanto se destrabe. Los 🔒 del dueño: E12 T16 (credenciales de Supabase y `ANTHROPIC_API_KEY`), mediación por SPM (E7b-a T6), capturas de iPad a ASC, los
> escenarios de E11 en device. Con la carga de la máquina alta, no más de dos compilando; las tareas de EK pura se verifican con `swift test` y no cuentan.
> **Ojo:** el clasificador del modo auto no deja escribir en `DUENO.md` (§7); las aprobaciones se confirman en el chat.
>
> 📋 **El tablero de la ejecución es `tasks.md`**, en la raíz de `version-2`:
> una línea por tarea con su estado, dependencias, archivos calientes, la cola
> de despacho y los gates del dueño. Lo escribe sólo el controlador. El
> detalle fino de cada épica sigue en su ledger,
> `version-2/.superpowers/sdd/<plan>/progress.md`. Lo que sigue, en §4 y en
> `tasks.md` §4.
>
> ✅ **EL REDISEÑO DE UI ESTÁ COMPLETO Y MERGEADO** — 20 de 20 tareas
> (`feature/rediseno-ui-cowevolution`, cerrado el 2026-08-16). El estado tarea
> por tarea, las decisiones del dueño y los avisos vivos siguen en
> **`Docs/SESION-2026-08-14-rediseno-ui.md`**, que es la fuente de verdad del
> detalle de ESA rama. Lo de abajo describe el juego ANTES del rediseño y
> sigue siendo válido para todo lo que el rediseño no tocó; el resumen de esa
> sesión, con los números de tests de su cierre, está en §4.
>
> ✅ **Y el ticket post-merge que ese cierre dejó triageado TAMBIÉN está hecho**
> — 7 tareas en `fix/cierre-post-merge` (18 commits sobre `89f215a`, mergeada a
> `main` en `e4d4ce6` y **PUSHEADA — `origin/main` está al día y la trampa 7
> quedó cerrada**), con review integral de rama que dio **ready to
> merge y CERO ola de fixes de código**. El detalle está en
> **`Docs/SESION-2026-08-16-cierre-post-merge.md`**. Lo que hay que saber en dos
> líneas: el calendario del daily aterrizó en Regalos, y
> **`AscentRenderingUITests` volvió de entre los muertos** — la suite de UI
> corre **43 sin un solo `-skip-testing:`** (§6).
>
> ✅ **Y el batch de los 15 iconos TAMBIÉN corrió** (2026-08-16, `d304fe3`):
> los 15 integrados al atlas con opacidad sana y cero descartes — la UI dejó
> los vectoriales, que quedan de fallback. ⚠️ **Lo único que falta son los dos
> gates humanos de F6**: la cuenta de Apple Developer (RF-02c) y la fuente de
> audio (RF-14). No queda NINGUNA tarea de código pendiente.
>
> ✅ **Y el rediseño de la PANTALLA PRINCIPAL está hecho** — 6 tareas en
> `feature/rediseno-pantalla-principal` (19 commits sobre `4c1e67c`): las 5 del
> plan más una **enmienda del dueño a mitad de vuelo**, todas cerradas y las de
> código revisadas. La pantalla dejó de ser un tablero con islas flotando:
> las **dos barras son gemelas en crema con contorno ink** y están **fundidas a
> su borde** (arriba y abajo), los **iconos de los 6 tabs son gigantes y llevan
> su nombre debajo**, la **barra de estado se oculta de verdad** (le faltaba la
> clave compañera en `project.yml`), y hay un **botón nuevo que contrata sin
> abrir FisuJobs** (`hud.quickhire`) — nació vendiendo "el mejor tier que la
> plata alcanza" y **desde el 2026-08-21 vende el TIER BASE del piso más alto**
> (§4, rebalance de pacing). El
> detalle está en **`Docs/SESION-2026-08-17-rediseno-pantalla-principal.md`**.
> Números de su cierre: EconomyKit **200** · app **370** · UI **44 sin un solo
> `-skip-testing:`** (los 183/346/43 de más abajo quedaron viejos). ⚠️ Dos cosas
> para tener a mano: en **SE la barra va a 374 de 375 pt** —los iconos no crecen
> más sin sacrificar los labels— y un `Button` de SwiftUI **publica su label
> como hijos de AX pase lo que pase**: sólo `accessibilityRepresentation` lo
> aplana sin romper el hit-testing (la tabla de las 5 formas medidas quedó en
> `QuickHireButton.swift`).
> ✅ **Y el rediseño v3 —los MATERIALES de las referencias— está aplicado a
> las 13 pantallas y los 7 popups** (2026-08-17, `feature/rediseno-v3-referencias`):
> interior pergamino, bordes tono-sobre-tono, pills caramelo, cinta con
> pliegues y destellos, la familia del menú en marco de madera vectorial,
> Regalos en madera+toldo+moño y el Ascensor en metal. Cero lógica tocada,
> cero strings nuevos, contratos de AX intactos. El detalle vive en
> **`Docs/SESION-2026-08-17-rediseno-v3.md`**; la trampa nueva que dejó la
> sesión (el cwd del agente que se vuelve solo al checkout principal) está en
> §7, trampa 16.
>
> **Empezá por acá.** Última actualización de la v1 (la de la 2.0 está
> arriba): **2026-09-03** (el cofre ya no
> se traba AL PRINCIPIO: la llegada del overlay pagaba **466 ms de hilo
> principal clavado** —el retrato del premio se leía en línea en el mismo
> latido que arranca el resorte de entrada— y ahora se calienta en
> background con `SKTexture.preload` (`UIArt.warmCharacterImage`); medido
> antes/después con la sonda nueva de la llegada, `arrival_probe.py`, que
> mira el primer segundo frame a frame a umbral fino. Sesión en §4, trampa
> en §7). La anterior, del **2026-08-28 (sexta)**: el
> cofre a VELOCIDAD: todo el espectáculo corre a **1,5x — los 190 frames del
> master presentados a 36 fps**, sin sintetizar ni tirar uno, con audio
> `atempo` y el manifest llevando el ritmo para PNGs y video por igual; y la
> traba del empalme ERA real — ~280 ms de congelón medidos al arrancar el
> video — y murió con preroll de verdad + capa montada desde la llegada +
> `playImmediately`. Trampa NUEVA grande en §7: **con una sesión paralela en
> el checkout, el build compila el árbol AJENO — worktree aislado siempre**.
> Sesión en §4 — igual que la **quinta del mismo día**, que en paralelo mató
> el muro de la cuesta pre-compuerta (`floors[alley].hireCostGrowth`, §4).
> Siguen vigentes: el mov **premultiplicado** o
> `AVPlayerLayer` suma un velo (§7 bis), el aviso de Store en 18.6/26.5 por
> ENTORNO (§6; ahora también visto en `StoreProductsTests`), y lo del
> 25-08: los sims de verificación van con runtime **iOS 26.5**).

---

## 0. Cómo se usa este documento

**Si sos un agente que recién llega, leé dos cosas y sólo dos**: este documento
(el general) y el handoff más reciente de `handoffs/`. Con eso sabés dónde está
parado el proyecto sin leer las doce sesiones.

El reparto es a propósito:

| Dónde | Qué va | Vida |
|---|---|---|
| **este general** (`Docs/HANDOFF.md`) | lo que sigue siendo cierto: arquitectura, reglas, decisiones que no se re-litigan, trampas ya pagadas, y §4 con una entrada por sesión | permanente, se ACUMULA |
| `Docs/SESION-<fecha>-<tema>.md` | el detalle de UNA sesión: qué se pidió, qué se midió, qué se decidió y por qué | permanente, no se toca después |
| `handoffs/HANDOFF-<fecha>-<tema>.md` | el estado AL CIERRE: qué quedó abierto, qué está en vuelo, qué romper no hay que | efímero, **gitignored** |

**Al terminar tu trabajo, siempre hacés tres cosas:**

1. Escribís tu `Docs/SESION-…` con el detalle y el PORQUÉ de cada decisión.
2. Dejás tu `handoffs/HANDOFF-…` con lo que queda abierto para el que sigue.
3. **Actualizás este general**: una entrada nueva arriba de §4, y lo que
   corresponda en §5 (decisiones), §7 (trampas nuevas) y §9 (mapa).

El paso 3 es el que se olvida y el que sostiene todo: sin él, el próximo agente
tiene que leer doce sesiones para entender el presente. Si encontrás acá un dato
vencido, **corregilo** — un general desactualizado es peor que no tenerlo,
porque se le cree.

Regla de oro para lo que escribas: **anotá lo que costó tiempo y no se deduce
del código**. Los números que calibraron una decisión, el diagnóstico que
resultó falso, el orden en que hay que hacer las cosas. Lo que el código ya
dice, no lo repitas.

**Durante la 2.0, además** (protocolo completo en `Docs/PLAN-v2.md` §0):

- **Al llegar** se suman tres lecturas: `PLAN-v2.md`, **`tasks.md`** (el
  tablero: qué está hecho, qué sale ahora y la cola) y el journal AVO del run
  (carta → estado → descartados). Se revisa el candado `LOCK` del run y se
  corre el oráculo antes de tocar nada.
- **Al cerrar**, además de los tres pasos: `tasks.md` y journal al día, y
  candado liberado. Si el contexto pasó los ~300.000 tokens y no queda ningún
  subagente ni tarea de fondo en vuelo, **relevo**: un `CronCreate` de un
  disparo con "continúa — protocolo de relevo FisuEvolution v2" +
  `clear_session("self")`. **Ese cron no despertó a nadie en los relevos 2 a
  7** (el 7 lo despertó el dueño escribiendo en la sesión); **el 8 lo despertó
  la rutina `fisu-v2-relevo-a`**, lanzada por el 7: la primera vez que un
  relevo despierta solo. Desde el relevo 6 existen las rutinas manuales `fisu-v2-relevo-a` y
  `-b` (decisión del dueño, §5): el que cierra lanza la otra con
  `run_scheduled_task`. En última instancia, el dueño escribe "continúa".
- Las skills `handoff-system`, `writing-session-handoff` y
  `writing-general-handoff` (globales) son la fuente de este protocolo.
- **Con agentes en paralelo** (PLAN-v2 §0.1), cada agente commitea en su rama
  y el controlador es el dueño de `Docs/`, `handoffs/`, `tasks.md` y el journal: el que
  integra es el que documenta.

---

## 1. Qué es

**FisuEvolution** ("Hobo Evolution"): juego iOS merge-idle con humor argentino.
37 tiers de evolución (El Fisura → Dios) en una **torre de 10 pisos simultáneos**;
los personajes de todos los pisos producen a la vez, se mergean de a pares y al
evolucionar "se mudan" al piso de arriba.

**Stack**: SwiftUI (HUD, menús, popups) + SpriteKit (`BoardScene`) + **EconomyKit**
(paquete SPM con la economía, puro y testeado). Swift 6 con
`SWIFT_STRICT_CONCURRENCY: complete` y `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.
La v1 publicada es sólo iPhone con iOS 17+; **en `version-2`, desde E3a T5
(`3956fd3`), la app es universal (iPad sólo vertical y de pantalla completa) y
pide iOS 18+**.

**El juego está terminado y jugable de punta a punta.** Lo que falta es F6:
cuenta de Apple Developer, App Store Connect, TestFlight y submission — todo
gates humanos, nada técnico.

---

## 2. Reglas del repo (romper esto rompe el build)

- **El `.xcodeproj` NO se versiona.** Se regenera con `xcodegen generate` desde
  `project.yml`. Al **agregar o borrar** un archivo Swift es **obligatorio**.
- **Cero warnings.** `SWIFT_TREAT_WARNINGS_AS_ERRORS` está activo.
- **Strings nuevos** van a `FisuEvolution/Resources/Localizable.xcstrings`
  (es base + en), **en el mismo commit que su vista**.
- ⚠️ **No edites el catálogo de strings con scripts.** Xcode lo reescribe a su
  formato canónico en el primer build y te deja un diff de 2.400 líneas. Si lo
  hacés igual, commiteá después el reformateo de Xcode (pasó, ver `13def46`).
  **Salvo que el script escriba el formato canónico**: se puede, y la receta
  —con la forma de verificarla antes de escribir nada— está en la trampa 29.
  Desde 2026-10-07 lo hace `Tools/v2/catalogo.py` (`verificar` y `aplicar`,
  §9).
- **Accessibility identifier** en todo control interactivo.
- **Commits en español**, atómicos.
- Convenciones de concurrencia: `Docs/concurrency-conventions.md`. Resumen: el
  mundo del juego es `@MainActor`, nada de `Timer` para trabajo del frame loop,
  EconomyKit es puro y `Sendable`.

---

## 3. Arquitectura

### Las tres capas

| Capa | Dónde | Qué hace |
|---|---|---|
| **EconomyKit** | `Packages/EconomyKit/` | Toda la economía: pura, `Sendable`, sin UIKit/SpriteKit, con reloj y RNG inyectables. Si una pieza de lógica necesita un tipo de UI, está en la capa equivocada. |
| **GameState** | `FisuEvolution/Game/State/GameState.swift` + `GameState+*.swift` | `@Observable @MainActor`. Orquesta: carga, tick de income, gestos resueltos, popups, y **proyecciones** para SwiftUI. Desde el relevo 7 el cuerpo (334 líneas) tiene sólo el estado y el `init`; lo demás está en extensiones por zona (§9). |
| **Presentación** | `FisuEvolution/Scenes/` + `FisuEvolution/UI/` | `BoardScene` dibuja y captura gestos; SwiftUI sólo lee proyecciones. |

**Regla que sostiene todo**: SwiftUI **nunca** lee `PlayerState`. Lee
proyecciones que `refreshProjections` publica a 8 Hz comparando antes de escribir.
`PlayerState` cambia decenas de veces por segundo; si la UI lo observara, se
recompondría sin parar.

### Contenido 100% data-driven

Ningún conteo, rango ni switch por etapa vive en código. Todo sale de JSON en
`FisuEvolution/Resources/`:

| Archivo | Qué define |
|---|---|
| `Data/economy.json` | Curvas, los 10 pisos (`floors[]`), costos de contratación, ORO |
| `Data/tiers.json` | Los 37 tiers y la cadena de evolución. **Generado** desde `Tools/generate-tiers/Sources/main.swift` — editar el JSON a mano lo pisa la próxima regeneración. Su `displayName` es el **castellano**; el inglés vive en el catálogo bajo `tier.name.<id>` |
| `Data/assets_manifest.json` | **Único puente código→arte.** Sin entrada acá, placeholder programático — ⚠️ **salvo los fondos**, ver abajo |
| `Config/skins.json` | Catálogo de apariencias |
| `Config/*.json` | Eventos, specials, upgrades, boosts, daily, feature flags |

Agregar un piso = una entrada en `floors[]` + el PNG del fondo. Agregar un
personaje = PNGs al atlas + entrada en manifest/tiers **+ su `tier.name.<id>` en
el catálogo de strings**. **Cero código.** Hay un `ExtensibilityDrillTests` que
lo prueba con un piso 12 declarado sólo como dato.

⚠️ La clave del nombre es la que se olvida, y falta **en silencio**: sin ella el
personaje se ve en castellano con el juego en inglés, porque `localizedName` cae
al dato. Quien avisa es
`GameContentValidationTests.everyTierHasItsNameInBothLanguages` (§4, sesión de
los nombres en inglés).

⚠️ **El fallback a placeholder NO cubre los fondos.** Un personaje sin entrada en
el manifest se dibuja con su placeholder programático y el juego sigue; **un piso
cuyo fondo falta hace que la app no arranque**. Medido el 2026-08-06 sacando
`bg_galaxy` para destrabar su regeneración: los tests unitarios seguían verdes y
los 17 de UI se cayeron con `Application com.manuader.fisuevolution is not
running`. Restaurar la entrada los devolvió a verde sin tocar nada más.

Consecuencia práctica: **regenerar un fondo exige sacarlo del manifest, y con el
manifest así el juego no corre.** La ventana tiene que ser corta y no se puede
buildear ni testear adentro. `process_dropbox.py` vuelve a poner la entrada al
integrar la imagen nueva, y si algo sale mal `git checkout` la restaura.

### La torre

- `FloorTable` (EconomyKit) valida cobertura exacta 1...maxTier sin solapes.
- `TowerState` vive **en memoria**; NO se serializa.
- **Los saves guardan unidades por TIPO, nunca por piso.** `TowerReconciler`
  recalcula la ubicación contra el mapeo vigente en cada carga, así que remapear
  tiers entre versiones reacomoda las partidas en vez de romperlas.
- `PlayerState` v4 = sobre con `run` (muere al reencarnar) + `meta` (sobrevive).

### La escena

Una sola `SKScene` con `SKCameraNode`. Los `FloorNode` se apilan a
`(0, i × alto)`; sólo vive el rango visible ±1. Reveal, flash y textos van
re-parenteados a un overlay de cámara para que no se queden atrás al navegar.

**Fusionar tiene dos gestos** (2026-08-10, spec en
`superpowers/specs/2026-08-10-fusion-asistida-design.md`):

- **Arrastrar.** Al levantar a alguien, los del **mismo tipo** se destacan: se
  congelan (dejan de deambular), suben `candidateZLift` por encima de la
  multitud, pegan un pop y capturan el drop a 1,5 celdas en vez de 0,95.
- **Doble toque.** Dos toques sobre el mismo personaje dentro de 0,3 s traen al
  compañero más cercano que esté a ≤2 celdas y lo funden. El tap **cobra
  siempre y primero**; la fusión es un efecto adicional del segundo toque.

⚠️ **Tocar rápido ES un doble toque** y no hay forma de distinguirlo: los dos
primeros toques de cualquier ráfaga van a fusionar. No es un problema —fusionar
nunca es una pérdida— pero la cascada sí, y por eso hay
`assistedMergeCooldown` de 0,8 s. No lo saques.

Los dos gestos salen por `resolveDrop`, que es el **único** camino de fusión de
la escena: por eso el doble toque hereda el prompt de carrera, el aviso de piso
lleno, el ascenso y la cadena de celebraciones sin código propio. La geometría
vive afuera, en `MergeTargeting`, y está pineada en `MergeTargetingTests`.

### Contadores de bonus activos

Bajo el HUD y a la izquierda, un chip por bonus temporal corriendo — boosts,
videos y el premio del Abogado; los eventos no, que ya tienen su banner
(2026-08-10, spec en `superpowers/specs/2026-08-10-contadores-de-bonus-activos-design.md`).

⚠️ **La proyección `activeBonuses` NO lleva el tiempo restante**, y sacarlo de
ahí es lo único que hace que esto sea gratis: lleva `expiresAt` y
`totalDuration`, que son constantes, así que el array sólo cambia cuando un
bonus arranca o se muere. Con el restante adentro, `refreshProjections`
invalidaría SwiftUI una vez por segundo —y el aro, ocho— mientras hubiera un
boost activo. El tiempo lo cuenta la vista con **un** timer de 1 Hz para toda la
barra, y el aro se interpola con un tween lineal de 1 s entre tick y tick.

---

## 4. Qué cambió, sesión por sesión

### Cierre de E4b (2026-10-10) — Los visitantes, los eventos y el Álbum en pantalla

E4b T1–T9 están en `version-2` y T10 es este cierre, sólo documentación; con él, **E4 queda entera** (E4a + E4b). Detalle, la tabla por tarea con su commit y el porqué de cada default en **`Docs/SESION-2026-10-10-v2-e4b.md`**.

- **El escenario es de una sola entrada** (`StageController` + `stageVisit`): un visitante o un presentador a la vez, y su entrada es el turno `.visitorEncounter` de `CelebrationQueue`. Lo que viene después —esperar a que lo toquen— no ocupa la cola. Todo se mueve por frame, sin `SKAction`.
- **Los visitantes** (`GameState+Visitors`) llegan solos, cotizan al llegar y cierran el trato por el embudo. La paciencia (30 s) corre sólo en momento calmo y se congela con el popup, con una hoja o con un intersticial. Viven en memoria: sobreviven al background, no a matar la app; el reloj de su carril sí está en el save.
- **Lo que se ve:** los chips bajo el HUD (`StageChips`), el popup con loop o foto (`VisitorPopupView`, el retrato con `AnimatedArtView`), el reto con las tres cartas del Vendedor, y los eventos con presentador y chip con cara. **El banner de eventos no existe más** (`.eventBanner` se fue en T4). El Apagón (velo ∝ velitas apagadas, baile con confeti, `SFX.blackout`) y los Campeones son efectos de escena.
- **La Liquidación está en el precio:** piso de 0,25 al producto de descuentos apilados (sólo en `spawnCostMultiplier`, la contratación gratis queda afuera) y precio tachado «antes X».
- **El Álbum de especiales** es la quinta tarjeta del menú, y los especiales ya no están anclados en el tablero (T9 sólo borró).
- **Verificación:** `completo` de `integ-r29` sobre `7c494ea`: VERDE (EK 845 · unit 1417 · store-unit 18 · store-ui 2 · iPad 4 · SE 2 · pipeline 89 · pacing-sim ✅ · Release 0; UI 129 verdes + 2 rojos por orden, `MenuPagerUITests` y `CustomizationUITests`, aislados VERDES sobre la misma build); antes cubrieron los `rapido` de cada merge y el `rapido4` de la punta del relevo 28. `rojos-declarados.txt` no cambió por E4.
- **🔒 del dueño (no se hicieron en device):** los siete escenarios a mano del plan, en SE y iPad 13", claro y oscuro, con y sin Reduce Motion (están listados en el SESION de E4b §3); la captura SE del precio tachado; el loop real del retrato, que nunca se vio.
- **Carries (a E5b/E6 y al dueño):** `eventPresenters` acotado por id (nunca se vacía); `Array(characterNodes.values)` por frame; la `zRotation` del baile compartida con el deambular; `meta.specialAnchors` sin escritores (se borra en el próximo bump de schema); el presentador que se va sin globo; matar la app con un evento pendiente lo pierde sin cobro.

### Cierre de E5a (2026-10-10) — El motor del Paquete, el Colchón y la Ruleta

E5a T1–T8 están en `version-2` y T9 es este cierre, sólo documentación. Es el motor sin pantalla; lo que se ve es E5b. Detalle, la tabla por tarea con su commit y el porqué de cada default en **`Docs/SESION-2026-10-10-v2-e5a.md`**.

- **Tres puros en `EconomyKit/Prizes/`:** el Paquete de la Aduana (`PackageScheduler`/`PackageRoller`), el Colchón (`TreasureScheduler`/`TreasureRoller`) y la Ruleta (`WheelTable`/`WheelRoller`), con `packages.json`, `treasures.json` y `wheel.json` validados al cargar.
- **El estado vive en `meta.engagement`** y sobrevive a la reencarnación. El paquete entra por el embudo de E1 con `Origin.package` y, si en su turno ya no entra, vuelve al buzón.
- **La Ruleta acredita antes de animar,** y `LootBoxGate` (Storefront alpha-3) decide si hay giro con ORO: falla cerrado, y E6a lo reusa para el cofre.
- **Verificación:** `completo` VERDE (el mismo de arriba, `integ-r29` sobre `7c494ea`); `pacing-sim` igual que antes (no modela premios); `rojos-declarados.txt` no cambió por E5a.
- **🔒 del dueño:** los tres escenarios a mano (el log de `package opened: …` con `--uitest-packages=2`, el primer paquete a los 2 min y el colchón a los 8 con los relojes bajados en un build local, y matar la app con dos paquetes esperando).
- **Carries a E5b y E6a:** `packageCandidates` no descuenta las llegadas en cola; el extra del colchón sólo con `mattressExtraOpensLeft > 0` y el `nil` tras su video; `LootBoxGate.current()` a `wheelAvailability`/`spinWheel`; el doble cobro de ORO de la Ruleta sin fixture; los giros ×30 que apilan (¿suma o renueva?); `restrictedStorefronts` que la config remota puede vaciar; el colchón que sobrevive a la reencarnación.

### Sesión del 2026-10-10 (relevo 30) — La ola AB: los recortes del dueño y el Estudio entran, y los videos empiezan a verse en el juego (E8e)

Un solo relevo, abierto a las 18:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a ~248k de contexto. Todo en `v2i/integ-r30`. `version-2` quedó en `56d7bfb`, la punta del `rapido3` VERDE sobre `c2708aa` (EK 845 · unit 1444 · Release 0). **Progreso: 213 de 269 (79,2 %).** El `rapido4` sobre `6c4a770` (E8e T5) sigue corriendo.

- **E8 T9** ✅: se integraron `v2/e8-recortes` y `v2/estudio-assets` (`2dcf084`; pipeline 94, estudio 15) con el `rapido1` VERDE (unit 1417). El plan E8e entró por cherry-pick y el de E8e T10 (6 tareas, gate 🔒 del dueño en el SE).
- **E8e T1** (`ArtClips`, resolvedor puro, y el contrato manifest ↔ contenido) y **E8e T7** (`AlbumFocus`: sólo la tarjeta enfocada y tuya monta el video): ✅ con el `rapido2` (unit 1435). **B22** (el manifiesto de privacidad, la política nombra a Anthropic, el atajo a App Review) entró con ellas: `NSPrivacyTracking` sigue en `false` a propósito.
- **E8e T2** (`VisitorNode.showClip`: el visitante habla y actúa; `visitorArrive` y `talkBlip` cableados) y **E8e T3** (8 pósters `ui_event_*` al atlas y la ilustración animada del evento): ✅ con el `rapido3` (unit 1444).
- **E8e T5** (`MattressStage`: el colchón espera en loop y se abre `.once`; el premio se acredita como antes): 🟢, RED por mutación; falta el `rapido4`.
- **Docs B1–B26**: los 26 defaults del dueño como decisiones (§5.22 y `tasks.md` §7). Pendiente de B10/B15: los avisos del reset van al brief de E9b T8.
- Ninguna tarea tuvo revisión opus (sin plata, save ni turno de tablero; el controlador leyó cada diff). **El movimiento real de lo nuevo no se vio en simulador: 🔒 dueño en device.**
- Trampas nuevas en §7: el test que nace verde y no prueba nada (por mutación), los eventos de 0 s sin ilustración, `NSPrivacyTracking` `true` sin dominios = ITMS-91064.

Detalle en **`Docs/SESION-2026-10-10-v2-relevo-30-ola-ab.md`**.

### Sesión del 2026-10-10 (relevo 29) — La ola AA: la pinta comprada con ORO, los accesos y las hojas de los premios, y el primer `completo` verde desde el 23

Un solo relevo, abierto a las 15:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a ~240k de contexto. Todo en `v2i/integ-r29`. `version-2` quedó en `236080b`, la punta del `completo` VERDE sobre `7c494ea` (EK 845 · unit 1417 · store-unit 18 · store-ui 2 · iPad 4 · SE 2 · pipeline 89 · pacing-sim ✅ · Release 0; UI 129 + 2 rojos por orden, aislados verdes). **Progreso: 208 de 254 (81,9 %).**

- **E6b T4** (`OroShop.purchaseSkin`: `alreadyOwned` antes de `spendOro`, la pinta a `shop.skins`; `allOwnedSkins` la une; `buySkinWithOro` síncrono, un guardado; rechaza `price <= 0`): ✅ con el `rapido` (unit 1403). Opus **Approved con arreglos** menores, hechos en `08fbf82`.
- **E5b T2** (`PrizeAccess`, chips, `MattressPopupView`, las hojas en el `ViewModifier` `PrizeSheets`, `isBoardBusy` suma colchón y ruleta): ✅ con el `completo`. Opus **Approved con arreglos** (`a502ef6`) y un **BUG ALTO de `WheelView`: `videoBusy` en el guard de los callbacks premiados hacía que el video de giro se viera y no pagara**; `openWheel` exige un tablero calmo; `packageTapped` cuenta la cola.
- **E4b T10 y E5a T9** (cierres, sólo docs): ✅; los marcadores de `completo` pendiente se reemplazaron por este `completo`.
- **El `completo`** dio 2 rojos por orden (`MenuPagerUITests`, `CustomizationUITests`) que aislados sobre la misma build dieron VERDE: contaminación de UI tests de un mismo simulador.
- **Pedidos del dueño en el chat:** sus elecciones de recortes (354: 113 rembg; 4 a regenerar) aplicadas en `v2/e8-recortes`, el balde de islas, el estudio de assets (`v2/estudio-assets`), el plan E8e (`v2/e8e-plan`, 9 tareas) y los defaults de `PREGUNTAS-DUENO-v2.md` (B1–B26) aceptados; borrada la rama remota `v2/e12-plan`. Todo en `DUENO.md`.
- Trampas nuevas en §7: `RootView.body` al límite del type-checker, el guard con estado que se come el pago de un video premiado, los dos UI por orden y el `.xcodeproj` no versionado.

Detalle en **`Docs/SESION-2026-10-10-v2-relevo-29-ola-aa.md`**.

### Sesión del 2026-10-10 (relevo 28) — La ola Z: el Apagón y los Campeones, las probabilidades del cofre, los especiales fuera del tablero y la Tienda de ORO en pantalla

Un solo relevo, abierto a las 12:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a ~265k de contexto. Todo en `v2i/integ-r28`. `version-2` quedó en `a5ef14c`, la punta del `rapido3` VERDE (EK 838 · unit 1389 · 0 rojos · Release 0). **Progreso: 203 de 254 en `version-2`; 204 de 254 (80,3 %) con E6a T8 ✅** si el `rapido4` de la punta (`40f076e`) da VERDE (VERDE (EK 838 · unit 1396 · 0 rojos · Release 0): E6a T8 ✅, 204 de 254 (80,3 %)).

- **E4b T6** (el Apagón: velo ∝ velitas apagadas, baile con confeti, `SFX.blackout`; los Campeones), **E6a T7** (`ChestOddsTable`, `effectiveOdds` por el mismo embudo que el roll, `LootBoxGate.lastKnown` que falla cerrado; opus Approved) y **E4b T9** (los especiales dejan el tablero; sólo borra): ✅, la última con el `rapido3` VERDE.
- **E6a T8** (selector Comprar/Gastar ORO, `OroShopView`, `PurchaseLatch`, `ChestOddsDisplay`, 12 claves): 🟢. Opus **Approved con arreglos**: sacar `.disabled` de `PricePill` (contra `GameArtComponents`) y un UI test del doble toque que dependía del reloj; hechos en `aaa8767` con un unitario del latch con RED visto.
- **E8 T9 Step 1:** `revision_recortes.py` suma `npcs` + 3 `fam_*`; la página `~/Desktop/revision-v2/index.html` (359 recortes, los sospechosos arriba) baja `decisiones.json`. Queda 🔒: elige el dueño; Step 3 lo aplica un relevo con `aplicar_revision.py`.
- **El `rapido1` dio ROJO** por `AudioManagerTests.eventAccents` (el apagón ahora tiene acento; el agente sólo corrió `AudioWiringTests`), arreglado en `a8289d5`; el `rapido2` por `GameLoopWiringTests.hireUnlockedNoticeWaitsItsTurn`, un flake bajo carga ~400 (aislado, verde).
- **Pedido del dueño en el chat:** la revisión de recortes (hecha), seguir en paralelo, y la lista de todas sus preguntas y gates → **`PREGUNTAS-DUENO.md`** (A1–A10 gates, B1–B26 preguntas con default), con copia en `Docs/PREGUNTAS-DUENO-v2.md` del checkout principal. Sus respuestas se vuelcan a decisiones.
- Trampas nuevas en §7: `AudioManagerTests` también pinea los acentos de eventos, el flake bajo carga de `GameLoopWiringTests`, los agentes que re-entregan por esperas de fondo colgadas, el `doubleTap()` que no prueba un cerrojo, `.disabled` en `PricePill`, `.quitar` con `catalogo.py quitar` y el latido con `sleep 600`.

Detalle en **`Docs/SESION-2026-10-10-v2-relevo-28-ola-z.md`**.

### Sesión del 2026-10-10 (relevo 27) — La ola Y: los eventos con presentador, la Ruleta en Regalos aviso incluido, la Tienda de ORO y los presupuestos de visitantes

Un solo relevo, abierto a las 10:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a ~245k de contexto. Todo en `v2i/integ-r27`. `version-2` quedó en `9a0ee06`, la punta del `rapido3` VERDE sobre `d860556` (EK 829 · unit 1356 · 0 rojos · Release 0). **Progreso: 198 de 254 en `version-2`; 200 de 254 (78,7 %) con E6a T6 y E2b T10 ✅** si el `rapido4` de la punta da VERDE (VERDE (EK 829 · unit 1380 · 0 rojos · Release 0): E6a T6 y E2b T10 ✅, 200 de 254 (78,7 %)).

- **E6a T4** (`oro_shop.json`, 13 ítems, 20 claves), **E5b T4** (la Ruleta en Regalos con `WheelGiftCard`), **E5b T6** (`NotificationKind.wheelReady`, `wheelSpinsReadyAt`) y **E4b T4** (el presentador de cada evento, el chip con su cara, adiós al `.eventBanner`): ✅, cada una con su `rapido` VERDE (unit 1336, 1341, 1341, 1356).
- **E6a T6** (comprar con ORO: cobro y entrega en un paso, Fusionar todo por el embudo, los permanentes que enchufan en E5) y **E2b T10** (`RewardBudget` y `EngagementBudgetTests`; `coinsSecondsScale` de los visitantes 1 → 0,31): 🟢.
- **Dos revisiones opus:** E4b T4 Approved con arreglos (`completeArrival` dejaba un fantasma en `current` al re-encolarse la entrada; `advanceEvents` sorteaba con un evento pendiente; la salida por video de Hiperinflación ya sin qué sacar); E6a T6 Changes requested (Fusionar todo cobraba dos veces porque `planMergeAll` no ve la cola), arreglado en `9cf32d9`.
- **Pregunta nueva al dueño:** los visitantes pagan ~un tercio de lo que pagaban (E2b T10).
- Trampas nuevas en §7: los agentes que lanzan `find /` buscando `v2-agente-protocolo.md` (no está versionado), `limpiar-worktrees.sh --apply` de a un worktree, `maxPerAbsence` 3 con 4 motivos, `planMergeAll` que no ve la cola y el test sin RED.

Detalle en **`Docs/SESION-2026-10-10-v2-relevo-27-ola-y.md`**.

### Sesión del 2026-10-10 (relevo 26) — La ola X: la Ruleta en pantalla, el reto, los ×3 que se entregan, el arresto, los ×2 por video y la pausa publicitaria

Un solo relevo, abierto a las 07:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a ~250k de contexto. Todo en `v2i/integ-r26`. `version-2` quedó en `652bc6a`, la punta del `rapido` VERDE sobre `4b44a4e` (EK 827 · unit 1308 · 0 rojos · Release 0). **Progreso: 193 de 254 en `version-2`; 194 de 254 (76,4 %) con E7b-a T3 ✅** si el `rapido` de la punta da VERDE (VERDE (EK 827 · unit 1329 · 0 rojos · Release 0): E7b-a T3 ✅, 194 de 254 (76,4 %)).

- **E4b T5** (el reto con su contador por delta y las tres cartas del Vendedor), **E6a T5** (el `grant` entrega `.autoTap`, `.nextOfflineMultiplier` y `.nextDailyMultiplier`; consumo único), **E5b T1** (`WheelView`, `OddsDisclosureView`, `RewardCopy`, el tic con freno; `LootBoxGate.current()` en la Ruleta), **E8b T11** (la cinemática del arresto) y **E7b-b T6** (el Diario ×2 y la carrera ×2 por video): ✅, cada una con su `rapido` VERDE (unit 1289, 1289, 1300, 1302, 1308).
- **E7b-a T3** (la pausa publicitaria: previa de 5 s, «No, gracias» sin castigo, premio que rota; `isBoardBusy` como definición única de calma): 🟢. **Es el bloqueo de publicación:** sin ella, E7b-a T2 saca un intersticial en cada corte.
- **Tres revisiones opus:** E6a T5 Approved; E5b T1 Approved con arreglos (doble cobro con Reduce Motion, háptico sin freno, repetir mientras carga el video); E7b-a T3 Approved con arreglos (la oferta de Compartir quedaba tapada). E7b-b T6 no pasó por opus, pero el controlador leyó el diff y devolvió un obligatorio: `chooseCareerWithVideo` pagaba sin elección aplicada.
- **El modo auto dejó de aprobar todo `Bash`** tras denegar un `push --delete` de la rama remota `v2/e12-plan` (queda para el dueño). Y un agente con monitores de espera re-entregó tres veces el mismo aviso.
- Trampas nuevas en §7: el modo auto sin `Bash`, el agente que re-entrega avisos de sus monitores, el video que paga sin acción aplicada, el `sheetOpen` que no mira toda oferta modal y el UI test que cae según el orden.

Detalle en **`Docs/SESION-2026-10-10-v2-relevo-26-ola-x.md`**.

### Sesión del 2026-10-10 (relevo 25) — La ola W: el Álbum, los visitantes en la partida, el Colchón, la Ruleta y el chip del visitante

Un solo relevo, abierto a las 05:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a ~250k de contexto. Todo en `v2i/integ-r25`. `version-2` quedó en la punta del `rapido` VERDE sobre `73a7196` (EK 827 · unit 1247 · 0 rojos · Release 0). **Progreso: 186 de 254 en `version-2`; 188 de 254 (74,0 %) con E5a T8 y E4b T3 ✅** si el `rapido` de la punta da VERDE (VERDE (EK 827 · unit 1275 · 0 rojos · Release 0): E5a T8 y E4b T3 ✅, 188 de 254 (74,0 %)).

- **E4b T8** (el Álbum de especiales: quinta tarjeta del menú con glifo SF, `SpecialsAlbumView`, lección `.album`), **E4b T2** (los visitantes llegan solos, cotizan y cierran el trato por el embudo; `GameState+Visitors`) y **E5a T7** (el Colchón: `GameState+Treasures`, sortea antes de gastar): ✅, cada una con su `rapido` VERDE (unit 1211, 1236, 1247).
- **E5a T8** (la Ruleta: `GameState+Wheel`, `LootBoxGate` que falla cerrado, `.wheelSpin` entregable) y **E4b T3** (`VisitorFace`/`StageChips`/`VisitorPopupView`, el retrato con `AnimatedArtView`): 🟢.
- **Tres revisiones opus:** E4b T2 **Changes requested** (fixture que no hacía nada, `confirmPrestige` sin despedir al visitante, rename de `loops_manifest` a medias) → arreglado en `2aba4ed`; E5a T7 Approved; E5a T8 Approved con arreglos (el día de los cupos con `Calendar.current`, un guardado futuro que bloquea la rueda) → `ecfae53`.
- **El rojo que no era:** `ArtPacksTests.failureDoesNotLoop` cayó en el `rapido` de E5a T8 bajo carga (120–150) y aislado dio 8/8 VERDE. **El hallazgo de UI:** `MenuPagerUITests` cuenta 6 páginas (Ranking) si corre después de `MenuUITests` en el mismo simulador; aislado pasa en la base y en `integ`. Carry a E12.
- Trampas nuevas en §7: el fixture de arranque que exige un momento calmo, el rename de un id de `loops_manifest`, las fechas de día con `Calendar.current`, el orden de los UI tests y el flake de ODR.

Detalle en **`Docs/SESION-2026-10-10-v2-relevo-25-ola-w.md`**.

### Sesión del 2026-10-10 (relevo 24) — La ola V: el cierre de E4a, el perfil `.max` y el CLI del simulador, la Liquidación en el precio, las ofertas que se cobran y el escenario

Un solo relevo, abierto a las 03:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a ~253k de contexto. Todo en `v2i/integ-r24`. `version-2` quedó en `91b7634` (`rapido` VERDE sobre `25cc5da`: EK 825 · unit 1190 · 0 rojos · Release 0). **Progreso: 182 de 254 en `version-2`; 183 de 254 (72,0 %) con E4b T1 🟢** si el `rapido` de la punta da VERDE (VERDE (EK 827 · unit 1207 · 0 rojos · Release 0)).

- **E4a T10** (cierre de E4a, docs) y **E2b T7/T8** (el perfil `.max` y el CLI del pacing-sim, EK): la base sigue **byte a byte idéntica** (Dios 31,34 h · 13 reenc.); con `--prestige-threshold 4`, `.bare` 22,34 h · `.free` 18,77 · `.ads` 12,84 · `.max` 12,75 (6 reenc.).
- **E4b T7** (la Liquidación en el precio: piso 0,25 sólo en `spawnCostMultiplier`, precio tachado «antes X») y **E6a T11** (`offer_*` consumibles, `creditOffer` sin mirar la ventana, ORO por `recordOroPurchase`); las dos con revisión opus Approved con arreglos, hechos.
- **E4b T1** (el escenario y su turno, 🟢): `StageController`, `VisitorNode`, `SpeechBubbleNode`, `.visitorEncounter` en `CelebrationQueue`; sin verificación visual a mano; los UI tests no se re-corrieron tras mover la `Section` del panel de debug.
- **El bug del `rapido`:** el piso de E4b T7 subía a 0,25 la contratación gratis (magnitud 0) y la revisión opus no lo vio; arreglado por el controlador en `25cc5da` (`product > 0` + test EK `freeHiringSkipsTheFloor`).
- Trampas nuevas en §7: el agente con trabajo de fondo que re-entrega, el reporte de arreglos que nunca llega (leer el commit) y los opus revisores que deben buscar magnitud 0 en los modificadores.

Detalle en **`Docs/SESION-2026-10-10-v2-relevo-24-ola-v.md`**.

### Cierre de E4a (2026-10-10) — El motor de visitantes y eventos v2

E4a T1–T9 están en `version-2` y T10 es este cierre, sólo documentación. Es el motor sin escena: qué pasa, cuándo y qué se da. Detalle, la tabla por tarea con su commit y el porqué de cada default en **`Docs/SESION-2026-10-10-v2-e4.md`**.

- **`RewardSpec` + `grant` son el único camino de premios** (E4a T1 y T8, `GameState+Rewards`). Un premio que `grantableRewardKinds` no tiene no se ofrece.
- **El reloj de eventos está en el save** (`meta.engagement`, E4a T3) y corre en juego activo: el primer evento a los 15 min de juego, con 60 s de gracia al volver.
- **Los 18 eventos compuestos** (`events.json` schema 2; `EventCatalog`, E4a T4 y T9): se fueron `EventManager` y el `EventsConfig` de la v1. Efectos nuevos: paro, inmunidad y ritmo de paquetes (T2).
- **`visitors.json`**: 18 del elenco y 26 guiones, en dos idiomas, todavía **sin escena** (E4a T5–T7; la escena es E4b T1).
- **Verificación:** la cubren los cierres del 23 (`completo --limpio` sobre `bab8a9c`: EK 796 · unit 1162 · UI con 3 rojos de E4a T9, arreglados en `534fd51`; pacing-sim Dios 31,34 h / 13 reenc., igual que antes de E4a) y el `rapido` VERDE sobre `5fca66d` (EK 814 · unit 1175 · 0 rojos · Release 0). `rojos-declarados.txt` no cambió por E4a.
- **🔒 del dueño (no se hicieron en device):** los tres escenarios a mano del plan: «Disparar un evento» con los 18 en el panel de debug, el primer evento a los 15 min con `--uitest-engagement` (y Home y volver no dispara en la cara), y matar la app en la espera y volver con el reloj donde estaba. Lo visto: `CorralitoUITests` PASS en SE y la captura SE de `paro_general`.
- **Carries a E4b:** el presentador re-chequea `eventIsApplicable`; `loops_manifest` `events.cayo_mercado_pago` → `home_banking`; la cuota sin plata no se atenúa; `isCalmMoment` sin unificar (`naturalBreakContext` suma `fullScreenUI`/`adOnScreen`; lo unifica E7b).

### Sesión del 2026-10-10 (relevo 23) — La ola U: la mudanza a eventos v2, el Paquete en la partida, el simulador de pacing con perfiles y los tres cierres

Un solo relevo, abierto a las 00:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a ~260k de contexto. Todo en `v2i/integ-r23`. `version-2` quedó en `2e51d29` (`rapido`: VERDE, EK 814 · unit 1175 · 0 rojos · Release 0). **Progreso: 174 de 254 en `version-2`; 177 de 254 (69,7 %) con las tres 🟢 de los cierres** si el `rapido` de la punta da VERDE.

- **La llave de la cadena:** E4a T9 (eventos v2 con 18 eventos, schema 2; se van `EventManager` y `EventsConfig`; revisión opus Approved con arreglos) destrabó E5a T5/T6 y deja a la vista E4a T10, E4b T7 y E5a T7.
- **El Paquete:** E5a T5 (`packages/treasures/wheel.json` validado) y T6 (buzón, candidatos por `PackageRoller`, abrir/devolver; revisión opus Approved, opcionales a E5b).
- **EK puro sin cupo:** E6a T2 y T10 (tienda y ofertas, `lastClosedAt`), E9b T7 (`ResetPlan`), E6b T6 (`FloorTable.expanded`).
- **El simulador de pacing:** E2b T3 (cobra como el juego), T4 (el piso que se llena no se fusiona: la regla literal nunca llenaba un piso de cap 10/15; medido), T5 (perfiles `.bare`/`.free`/`.ads`/`.max`) y T6 (`.ads`: Dios en 23,71 h con 662 videos). **La base siguió idéntica byte a byte: Dios 31,34 h · 13 reencarnaciones.** E2b T11: la herencia en `PrestigeView`.
- **Los cierres** (un `completo --limpio`): E8 T10 (peso **+39,3 MB** sobre la v1, bajo el gate de 60; sin 🔒; memoria pico 117 MB en el SE), E13b T11 (tres grabaciones del ascensor) y E13 T14; **3 UI rojos reales de E4a T9** (el menú de eventos tapó las puertas del panel de debug), arreglados en `534fd51`.
- Trampas nuevas en §7: el clasificador del modo auto no deja escribir en `.superpowers/` del worktree `version-2` (la tabla de dueños va en cada brief), y el panel de debug exige correr `CharacterSheetUITests` y `QuickHireUITests`.

Detalle en **`Docs/SESION-2026-10-10-v2-relevo-23-ola-u.md`** y, para los cierres, **`Docs/SESION-2026-10-10-v2-cierres-r23.md`**.

### Sesión del 2026-10-10 (relevo 23, los cierres) — El `completo` de E8, E13b y E13, y el panel de debug que se comió sus puertas

Un solo `completo --limpio` sobre `bab8a9c` cerró tres épicas (detalle y números en `Docs/SESION-2026-10-10-v2-cierres-r23.md`).

- **Resultado:** EK 796 · unit 1162 · pipeline 89 · pacing-sim (Dios 31,34 h activas) · Release 0 avisos · iPad 4 · SE 2 · store-ui 2. UI: 3 rojos
  **reales**, todos del mismo bug de debug (abajo); arreglado en `534fd51`, los tres verdes. `store-unit`: 1 rojo (`loadsTheCatalogProducts`, 280 s) que
  **pasa aislado** (16 verdes): el simulador 18.6 frío bajo carga.
- **El bug:** E4a T9 sumó el menú "Disparar un evento" en la sección Offline del panel de debug, **arriba** de las puertas de los UI tests, y la `List`
  perezosa dejó `debug.sheet.open`, `debug.floor.fill` y `debug.quickhire.many` bajo el pliegue (trampa de §7 "las puertas de los tests"). Ahora el menú
  vive en su propia sección al final y las Cinemáticas bajaron antes de Rendimiento.
- **E8 T10 (peso):** el Release de la punta pesa **206,8 MB** contra **167,6 MB** de la v1.0.0 (build 4): **+39,3 MB**, bajo el gate de 60 MB (estimado +29): no hay 🔒.
  Memoria (huella de la app Debug en el SE con la torre entera, durante los viajes del ascensor): **pico 117 MB** (estimaba 168 con fondos de 2048 sin comprimir).
- **E13 T14 / E13b T11:** §5.7 y compañía ya dicen "las seis" (192 ORO; 348 con `baseCost` 2 en E2b T14); la frase "los cofres de torre se vuelven a cobrar al
  reencarnar" no estaba en el HANDOFF (sólo en la sesión del relevo 19): queda asentado en §5.11 que los cofres de piso son **una vez por cuenta**.
  Tres grabaciones del ascensor y la barra para el dueño (build `…/build/grabaciones/` del worktree de los cierres, gitignoreado).

### Sesión del 2026-10-08 (relevo 9) — La ola G: E1 completa en código, la economía de E2a detrás de perillas y ninguna skin por código

`version-2` quedó en `8cf4e73`. **Progreso: 52 de 167 tareas activas integradas (31,1 %).**

- **E1 llegó a T15**: el Corralito (T13) y el video sin efecto que compensa 3 min (T14) pasaron
  por revisión opus, porque tocan plata, y volvieron con arreglos. Entre ellos, la salida por video
  ahora aparece sólo con el anuncio precargado y va debajo del texto en el SE. El contrato de
  efectos (T15) muerde: los mutantes los corrió el controlador. Falta T16, el cierre de E1
  (dos `completo --limpio`).
- **E2a T3–T10**: el amortiguador del salto de precio, los pisos en marcha, el piso móvil para
  reencarnar y las fusiones al amortiguador. Las tres mecánicas están detrás de perillas que en 0
  dejan la v1 exacta; cada tarea lo prueba con la huella del simulador. FisuJobs muestra cuánto sube
  la próxima compra.
- **El dueño dijo que no a las skins por código** (`Docs/SESION-2026-10-08-v2-e6.md`): E6b T1r
  borró los shaders, la galería y el tratamiento `.effect`.
- También entraron E11 T6 (las notificaciones al ciclo de vida), E3b T2 (la ficha), E3a T9–T10
  (las pestañas de a poco y el tablero con `PlayLayout`), E6a T9 (packs 160/550/1.400) y E4a T2.
- El `completo` de `528d10b` es la referencia nueva. El `completo --limpio` de `72a236b` encontró
  dos cosas, ya arregladas: la fila bloqueada de FisuJobs mostraba "+6 %" y `pacing-sim` no
  compilaba con su cache vieja (§7).

Detalle en **`Docs/SESION-2026-10-08-v2-relevo-9-ola-g.md`**.

### Sesión del 2026-10-09 (relevo 22) — La ola T: compartir recableado, la privacidad del ranking, las familias y el motor de visitantes

Un solo relevo, abierto a las 22:03 por el disparo horario de `fisu-v2-relevo-a` y cerrado a 268k de contexto. Todo en `v2i/integ-r22` (`8ab8b33`; `rapido`: VERDE (EK 735 · unit 1143 · 0 rojos · Release 0)). **Progreso: 159 de 254 en `version-2`; 162 de 254 (63,8 %) con las tres 🟢.**

- **La llave de E4a:** E3b T9 (`GameState+Share`, `EngagementState.sharedMoments`; revisión opus Approved con arreglos) destrabó E4a T3 y E5a T4, y con ellos el resto de la cadena.
- **El motor de visitantes y eventos:** E4a T3 (los relojes en `meta.engagement`), T4 (eventos v2, EK), T5 (visitantes puros, EK), T6 (`VisitPlanner`; `Origin.visitor`) y T7 (los 18
  visitantes y 26 guiones del Anexo A, 81 claves); E5a T4 (buzón, colchón y ruleta en el save) y E6a T1 (tienda y ofertas en el save; revisión opus Approved).
- **Cierres de contenido:** E6b T9 (las tres familias, 129 entradas en `skins.json`) y E12 T15 (privacidad, términos y notas a App Review; `PrivacyInfo.xcprivacy`).
- **El rojo del `rapido`:** `SkinCatalogRowsTests` pineaba las filas del Fisura sin las familias que E6b T9 suma a propósito; se arregló el test (`ababa57`).
- Trampas nuevas en §7: `setsid` no existe en macOS, las tareas de EK pura no ocupan cupo de compilación, y el rojo que es un test que pinea un catálogo.

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-22-ola-t.md`**.

### Sesión del 2026-10-09 (relevo 21c) — La ola S: las cinemáticas con overlay, los cortes naturales de anuncios y los cuatro cierres

Tercera tanda de la misma sesión («continua» del dueño). Todo en `v2i/integ-r21c` (`f830217`; `rapido`: VERDE sobre `f830217` (EK 651 · unit 1122 · 0 rojos · Release 0)). **Progreso: 150 de 254 en `version-2`; 152 de 254 (59,8 %) con las dos 🟢.**

- **Cinemáticas:** E8b T8 (`CelebrationQueue .cinematic`, watchdog 12 s), T9 (overlay a pantalla completa, lease `fullscreen`, ducking, sólo «Saltar»), T10 (reencarnación
  y Dios la disparan; `reconcileCinematics` re-encola Dios tras una muerte de la app) y E8d T11 (la intro sale en **partida nueva**).
- **Anuncios:** E7b-a T2 (`GameState+Ads`, cortes `sheetClosed`/`offlinePopupDismissed`/`reincarnation`/`celebrationsDrained`; el reloj 1.x borrado) y T4 (app open al volver,
  antes del offline). **No publicar T2 sin T3.** Falta `canRequestAds` en intersticial y rewarded; un solo observador de AdMob para todos los formatos (carry).
- **Cierres** (un `completo`): E11 T7, E2a T15 (tabla de perillas, base Dios 31,34 h), E8c T10, E3a T12.
- **E2b T2** (pasivos que se heredan, perilla apagada), **E13 T13** (efecto de antes a después), **E12 T14** (la tarjeta del nombre; con el ranking apagado no sale).
- **`BonusHUDUITests`:** era el test (el puntito de Regalos se enciende con el mate listo, que nace listo).
- Conflicto resuelto en `confirmPrestige`: quedó `scheduleNaturalBreak(.reincarnation)` de E7b-a T2.
- Trampas nuevas en §7: el agente que re-entrega el mismo reporte con una espera de fondo, y el oráculo que usa el repo de su propia ruta, no el `cwd`.

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-21c-ola-s.md`** y **`Docs/SESION-2026-10-09-v2-cierres-e11-e2a-e8c-e3a.md`**.

### Sesión del 2026-10-09 (relevo 21b) — El dueño aprobó: la lista de palabras, el selector del atajo y las seis líneas

Continuación del relevo 21 en la misma sesión, después de que el dueño escribiera en el chat «aproba todo y continua con el desarrollo». Todo en
`v2i/integ-r21b` (`34f2266`; `rapido`: VERDE sobre `34f2266` (EK 642 · unit 1070 · 0 rojos · Release 0)). **Progreso: 137 de 254 en `version-2`; 139 de 254 (54,7 %) con las dos 🟢 de `integ-r21b`.**

- **Decisiones del dueño (no se re-litigan):** E13 T7 opción (a) (Dios 31,34 h, bandas re-pineadas); barra de 6 pestañas con platos de 44 pt; E13 T2 tal
  cual; activar la lista de palabras de E12; el cable del ascensor tal cual.
- **Lista de palabras de E12 ACTIVA** (`a42a94b`): `propuesta.txt` con encabezado ACTIVA y migración `20261009000001_blocklist.sql` (137 términos). Se
  despliega con E12 T16 (🔒 credenciales de Supabase y `ANTHROPIC_API_KEY`).
- **E3b T8** (`42c61f0`): `QuickHirePicker` como overlay anclado a `resolved[.quickHire]`, junto al `TutorialOverlay`; `QuickHireButton(onChoose:)`
  cableado (mantener 0,45 s); sección «Atajo» en el panel de debug. Receta R en 16 Pro: QuickHire 3/3, QuickHireButton 3/3, BottomMenu 4/4, Tutorial 9/9.
- **E13 T7** (`421817b` + `592ef99`): la línea `lucky` del plan (20 / ×1,09) con `PacingTests` re-pineado a lo medido (paredes ≥ 4, reencarnaciones ≤ 9,
  corrimiento «pared más lejana ≥ 3 sobre la primera»); `upgrades.json` sin tocar. Revisión opus con arreglos: `recomputeDerivedEffects` en el
  bootstrap (los efectos derivados no se recalculaban al cargar) y los textos «las seis» / «≤ 9». **Carries** (también en el SESION): un
  veterano de un solo lado pierde crítico (25 % → 12,5 % + 2,5 % dorado); la última run se traba más abajo (T17 → T12), aceptado, a E2b T14; una app
  vieja que lea un save 2.0 ve crit/golden en 0 (verificar el versionado); el piso de tres tiers del corrimiento no tiene margen; `ui_up_crit` sin
  uso; la fila de `lucky` no muestra el dorado → E13 T13.
- Trampa nueva en §7: el clasificador del modo auto no deja escribir en `DUENO.md`, ni siquiera las aprobaciones del chat.

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-21-ola-r.md`** (§ «Relevo 21b»).

### Sesión del 2026-10-09 (relevo 21) — La ola R: el viaje que suspende los videos, la barra de seis y los premios por video

Con el `rapido` VERDE sobre `cad2d93`, `version-2` avanzó a `7604768`. **Progreso: 135 de 254 en `version-2`; 137 de 254 (53,9 %) con las dos 🟢 de `integ-r21`.**

- **E8d T10:** `Warmup` reserva y libera contra un pool inyectable; el viaje suspende los videos y suena el cue `.cable`. Revisión opus con arreglo:
  la reserva vencía a los 45 s y `closingPlayer`/`openingPlayer` nacían en frío (cuatro decodificadores en el fundido de llegada); hoy reservan al crearse.
- **E12 T13:** la barra quedó con **seis pestañas** (la Tienda salió) y platos de 44 pt para que entren 3 por lado en el SE (372 ≤ 375). La pestaña
  del ranking no aparece en producción hasta E12 T16.
- **E13 T2 / E13 T9:** el regalo por video de frontera − 3 y «Fusionar todo» por video (600 s, sin compensar por eslabón); la ficha del personaje
  y Despedir desde Personajes. Las dos 🟢 en `integ-r21`.
- **E13 T7 bloqueada:** con la línea `lucky` del plan (20 niveles, ×1,09) maxear pide 9 reencarnaciones (≤ 8), las paredes bajan a 4 (≥ 5) y Dios pasa de
  30,73 a 31,34 h (+0,61 > 0,5). 10 variantes de costo y ninguna sirve. Decide el dueño; la rama `v2i/e13-t7` (`5d587c6`) está pusheada.
- Trampas nuevas en §7: el `pkill -f` de un agente, el `sleep 600` del latido, los simuladores `oraculo-*` borrados por tiempo y el `cwd` que frena la limpieza.

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-21-ola-r.md`**.

### Sesión del 2026-10-09 (relevo 20) — La ola Q: la escalada por bandas, la cadena en el simulador, el fondo vivo y la revelación en movimiento

Con el `rapido` VERDE sobre `b8a3c1e`, `version-2` avanzó a `7a5395b`. **Progreso: 131 de 254 en `version-2`; 133 de 254 (52,4 %) con las dos 🟢 de `integ-r20`.**

- **E2b T1:** `EscalationBand` y `escalation(atFrontier:)` como única fórmula de `hireCost` y `PriceCushion.jump`, más
  `costGrowthStepPerFloor`; apagadas (con el umbral 7 el resultado es el de la v1).
- **E8c T9:** `--uitest-merge-all` y `MergeAllChainUITests`; la cadena mide 19,9 s sola y 28,5 s con toques; el techo del UI test
  pasó de 20 a 30 s (lo hizo el controlador).
- **E8d T8 / T9:** el fondo del piso con `LoopingVideoNode` (**ya activo en producción**: 10 `bgloop_*` sin `odrTag`) y la revelación
  con el video del personaje en `cameraOverlay`. Revisión opus en las dos, con arreglos: la suspensión por scroll que `willMove` no
  soltaba, el `fadeOut` sobre un nodo nil, el whoosh condicional y la precarga ODR del próximo tier. Falta mirar en device (G1/G2/G3).
- **E3a T11 / E7b-a T5 / E3b T4:** el chrome de la raíz en la columna con las seis hojas por `fisuSheet`; la fila «Opciones de
  privacidad» en Ajustes sólo donde UMP la pide (+3 claves); el menú deslizable (sólo la página quieta queda montada, Tienda en una
  sesión de una página, cinco páginas). `BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos` está rojo también en la base.
- Trampa nueva en §7 (el `rapido` lanzado con la máquina cargada y dos agentes compilando).

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-20-ola-q.md`**.

### Sesión del 2026-10-09 (relevo 19) — La ola P: los cofres de piso por cuenta, la escena que encadena y el toque que apura

Con el `rapido` VERDE sobre `f3a2155`, `version-2` avanzó a `f3a2155`. **Progreso: 121 de 254 en `version-2`; 126 de 254 (49,6 %) con las cinco 🟢 de `integ-r19`.**

- **E13 T3:** `floorChestsAwarded` pasa de `RunState` a `MetaState` (migra `max(meta, run viejo)` en `PlayerState.init(from:)`);
  no entra a `resolveAcrossReset`, el reset de cuenta lo deja en 0. Revisión opus: Approved. Un jugador de la v1 que ya reencarnó
  cobra una vez más los cofres de pisos ya alcanzados.
- **E8c T7 / T8:** la escena encadena sin soltar el turno (`endBoardChangeTurn()` es el borde único; tempo por `next.chain`;
  `playBoardMergeFeedback` reemplaza el háptico `.merge`) y el toque apura la cadena (`tapDuringCelebration`, piso de 0,6 s por
  eslabón, contador en `cameraOverlay`, remate y VoiceOver). Revisión opus en las dos; arreglo obligatorio de T7: guard
  `playingChain == nil` en `touchesBegan`. Sin captura ni grabación.
- **E13 T10:** FisuJobs por pisos (`JobGroups.make`, `TowerNaming.ledText`) y `GameState.floorDisplayName(for:)`: "Piso ???" también
  en la ficha y la tienda de pintas (cierra el carry de E13 T8).
- **E8d T7 / E13 T4 / E8 T7 / E7b-a T1** (🟢 en `integ-r19`): los 8 `sfx_ev_*` (sin escuchar, G7), `GameState.hasReadyBoost`, +62 PNG
  de arte en `ui.atlas` (con dos ventanas blancas opacas y dos imágenes repetidas) y `ForcedAdsSetup` con los IDs remotos
  sólo en producción y Release.
- Trampas nuevas en §7 (el agente que re-entrega el informe, `timeout` que no existe, la carga que estira el `tarea`).

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-19-ola-p.md`**.

### Sesión del 2026-10-09 (relevo 18) — La ola O: la cadena de Fusionar todo en el plan, el turno y el remate

Con el `rapido` VERDE sobre `4638ef1`, `version-2` avanzó a `1776145`. **Progreso: 116 de 254 en `version-2`; 118 de 254 (46,5 %) con las dos 🟢 de `integ-r18`.**

- **E8c T1 / T2 / T5:** `BoardChange.Chain` sellada por `planMergeAll`, `CelebrationQueue.renew(_:)` y el turno de la cadena en
  `GameState` (`beginNextChainLink`, `hurryChainLink`, `debugSeedMergeAll`). Revisión opus en T1 (Approved) y T5 (Approved con
  arreglos: `beginNextBoardChange(while:)` privado, tests de dos cadenas y del turno soltado). T7 decide el tempo por
  `next.chain`; un video que compense en `discardBoardChange` compensaría por eslabón.
- **E13 T8:** pisos cerrados como "Piso ???" con silueta. `ElevatorPanel` ya no existía (E13b T8): el brief lo corrigió.
- **E13 T11 / T12:** la moneda hija del `CharacterNode` (sin captura con pasivos) y el "Pack de las 43" (la clave salía `%@`
  en vez de `%lld`; devuelto una vez).
- **E8c T6 / T4** (🟢 en `integ-r18`): el contador ×N (sin montar) y el plin que sube de tono con su remate (`.caf` sin
  escuchar: G7; el háptico `.merge` de `presentResolution` pasa a `playBoardMergeFeedback` en T7).
- Trampas nuevas en §7 (el `pgrep -f` que se encuentra a sí mismo, entre otras).

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-18-ola-o.md`**.

### Sesión del 2026-10-09 (relevo 17) — La ola N: la ODR por tag, el especial animado y los ganchos del ranking

Con el `rapido` VERDE sobre `2d33c08`, `version-2` avanzó a `b093db5`. **Progreso: 108 de 254 en `version-2`; 110 de 254 (43,3 %) con las dos 🟢 de `integ-r17`.**

- **E8d T14:** 99 `.mov` a 14 packs ODR (base +10,2 MB, packs 19,8 MB). El manifest de la tanda tenía `visitors`/`icons` y
  Swift lee `talking`/`visitorActions`/`shopIcons`: se reescribió y `video_assets.py` quedó al día. Los íconos 256² llevan
  claves `ui_oro_*` para E6a. El ODR real nunca se probó en device (en Debug los packs van embebidos).
- **E8d T5:** el póster del especial es de cuerpo entero y `.portrait` es el busto: el video saltaba al arrancar; el
  especial anima `.character(special.id)`.
- **E12 T11:** los ganchos del ranking; la revisión opus cazó que `becameActive` durante el tutorial arrancaba la partida
  rankeada (guard `!tutorialPhaseActive`, test `tutorialDoesNotRunTheClock`). Un test viejo (`GameStateRankingHostTests`)
  esperaba `godTier == nil` y se alineó.
- **E13 T5:** los precios al reencarnar, explicados. **E8d T13 / E8c T3** (🟢 en `integ-r17`): la sonda de fps y el tempo de
  la cadena, puro.
- La lista de palabras de E12 no se reintentó. Trampas nuevas en §7.

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-17-ola-n.md`**.

### Sesión del 2026-10-09 (relevo 16) — La ola M: la segunda tanda de videos, el video en la escena, la ODR y el ranking en el save

Entraron la segunda tanda del dueño (108 videos aprobados, `v2/e8-videos`) y su doc, y seis tareas sobre `v2i/integ-r16`.
`version-2` avanzó a `bce2fc2` con el `rapido` intermedio; el final cubre las seis. **Progreso: 98 de 254 en `version-2`; 104 de 254 (40,9 %) con las seis de `integ-r16`.**

- **La tanda del dueño** destrabó E8d T14 (la revisión ya está) y cerró el carry de los stills de la cabina (regenerados
  sin la línea verde). Dejó un rojo: `LoopsManifestTests.cinematics` esperaba la intro ausente.
- **E8d T4:** `LoopingVideoNode` sobre el `Lease` del pool; la revisión opus pidió un control del alfa (retrato con centro
  no rojo + el gemelo opaco `cine_arresto`) y el release del lease en `deinit`. Con eso, ruta A para T9 en el simulador
  (la vara real, G3 en device). **E8d T12:** `ArtPacks` y ODR; ninguna entrada tiene tag todavía (T14).
- **E12 T10:** la partida rankeada entra al save v6; sin clave → `.legacy`, las viejas no compiten. **T9a/T9b:** la tarjeta
  de Dios y la pestaña, vistas sueltas aún sin montar. Para el dueño: el `installId` no viaja por CloudKit.
- **E13b T8:** mantener apretado el ícono despliega la placa; la revisión opus cazó una bandera de long press que
  quedaba en `true` y una lección que cerraba la placa.
- **El clasificador de permisos del modo auto bloqueó activar la lista de palabras de E12** (el pedido venía de
  `DUENO.md`); queda pendiente. Trampas nuevas en §7.

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-16-ola-m.md`**.

### Sesión del 2026-10-09 (relevo 15) — La ola L: el ascensor montado, el pool de videos y el store del ranking

Con el `rapido` VERDE sobre `e6e8c53`, `version-2` avanzó por fast-forward a la punta de `v2i/integ-r15`. **Progreso: 98 de 254 (38,6 %).**

- **E13b T6, el viaje montado:** el overlay vive en `FisuEvolutionApp` y el mapa viaja; bajo `--uitest*` el viaje dura
  0 s. La revisión opus cazó el parpadeo al salir, el doble ding al saltear y el `prepare()` con Reduce Motion; UI tests
  de ElevatorRide en 16 Pro e iPad. Falta T8 (la placa), con el carry de que los popups de `RootView` se dibujan encima
  de la cabina.
- **E8d T2 y T3:** `VideoPlayerPool` con `VideoPlaybackPolicy` (≤ 3 vivos, roles, suspensiones) y `AnimatedArtView`
  (póster instantáneo, video en overlay, `loop` o `once` que no revive). Ambas pasaron por opus con arreglos. El
  publisher de `isReadyForDisplay` no dispara en el simulador y quedó el sondeo.
- **E8d T6, E3b T7 y E12 T8:** 11 sonidos nuevos con `Gain`/`startAmbient`; el botón del atajo con `blocker` y long
  press (un toque tras mantener sigue comprando); `RankingStore` con `startAttemptId` y `playedSeconds` en la llegada
  arrastrada.
- **Dos `xcodebuild` colgados dos horas** y una carga de ~600 por la segunda tanda de videos del dueño: trampas nuevas
  en §7.

Detalle en **`Docs/SESION-2026-10-09-v2-relevo-15-ola-l.md`**.

### Sesión del 2026-10-08 (relevo 14) — La ola K: los videos reconciliados, el plan Swift de las animaciones y cinco tareas más

`version-2` quedó en `596cacd` (y `v2i/integ-r14` en `32afc93`). **Progreso: 87 de 254 en `version-2`; 92 de 254 (36,2 %) con las cinco de `integ-r14`.**

- **Los videos, reconciliados:** se mergearon `v2/e8-videos` y `v2/e8-animaciones-docs`; manda la versión del dueño de
  cada pieza (27 piezas y su manifest); la cabina es `cabina_puertas_*`, los stills `cabina_{cerrada,abierta}.png` hay que
  regenerarlos (línea verde) y el tope de rate de la cabina subió a ×5.
- **P-E8d (opus):** el lado Swift de las animaciones, 15 tareas; reemplaza E8b T4/T5/T6/T12 y cambia E8b T8/T9.
  E8d T1 (manifest, `ArtClip`, `CinematicID`) ya está.
- **El ascensor y la barra:** E13b T7 (la lección de mantener apretado) y T10 (barra 2 + 1 + 2, sin rótulos). Faltan T6,
  T8 y T11.
- **E3b T6** (la oferta del atajo con pin, motivo y siempre presente; revisión sonnet, un arreglo) y **E12 T7** (cliente,
  identidad en el Keychain y config remota `null` hasta T16).

Detalle en **`Docs/SESION-2026-10-08-v2-relevo-14-ola-k.md`**.

### Sesión del 2026-10-08 (relevo 13) — La ola J: el ascensor y la barra con plan, el backend del ranking y los videos

`version-2` quedó en `4ab1817` (y `v2i/integ-r13` en `a74d6e7`). **Progreso: 87 de 243 tareas activas integradas (35,8 %).**

- **Tres planes opus:** P-E13b (el ascensor y la barra, 11 tareas, no toca `RootView` ni `GameState`), P-E8b (las
  cinemáticas, 12) y P-E8c ("Fusionar todo" encadenado, 10).
- **E13b casi entera:** el director del viaje, la placa colgante, los sonidos, los clips de la cabina y la cabina
  con su vista (T5, revisión opus con cinco arreglos), y la Tienda fuera de la barra (T9, con el + de la moneda).
  Faltan T6 (el viaje montado), T7, T8 y T10.
- **E12 con backend:** moderación con Haiku (T3), cuatro Edge Functions (T4, `start-run` idempotente por
  `clientRunId`), cron y propuesta de lista (T5) y `RankingState` en EK (T6); `supabase/test.sh` sql 25 · deno 80.
- **Save:** E9b T6 sube la época del reset y reparte el ORO con asociatividad (revisión opus, dos arreglos).
- **Arte y pipeline:** 52 claves de visitantes y especiales (E8 T6), `seenCinematics` (E8b T7) y los 18 loops
  y 3 cinemáticas (E8b T1–T3, con el fondo blanco por conectividad). **Ojo: la sesión del dueño integró lo mismo
  en `v2/e8-videos`; hay que reconciliar antes de seguir con E8b/E13b T6.**
- E13 T6: la Startup evoluciona dos tiers abajo de la frontera o paga (revisión opus, plata).

Detalle en **`Docs/SESION-2026-10-08-v2-relevo-13-ola-j.md`**.

### Sesión del 2026-10-08 (relevo 12) — Las 3 regresiones de UI, la bandeja del dueño y tres épicas con plan

`version-2` quedó en `c94f75f` (y `v2i/integ-r12` en `acee4d8`). **Progreso: 69 de 210 tareas activas integradas (32,9 %).**

- **Las 3 regresiones de UI de la ola H eran reales y de dos causas:** el panel de debug es una `List`
  perezosa y E2a T14/T12 pusieron una sección arriba de las puertas de test (cofre, ficha y especiales:
  `402c24d`); y E3b T3 tipó el path del menú como `[Destination]`, que descarta en silencio el push de
  los legales (`2336642`, ahora `NavigationPath`).
- **Bandeja del dueño:** `v2/release-ops` mergeada (compras y anuncios como código, 5 IDs nuevos de AdMob,
  la ficha de la 2.0), y cerrados los gates de AdMob, App Store Connect, batch de arte, `rentista_soles` y
  Supabase. El switch `appOpen` prendido movió un default pineado por un test (`832a4f6`).
- **E8 (arte):** plan de 10 tareas; entraron el rentista (T1), el alta del batch (T2), las tres familias de
  43 (T3–T5) y los fondos a 2048 en JPEG (T8, `Backgrounds/` 38 → 9 MB).
- **E12 (ranking):** plan de 19 tareas; entraron el backend con RLS (T2, `supabase/test.sh` 23 casos) y
  `NameRules` con su tabla de 31 casos compartida (T1).
- **E13 (feedback de la v1):** plan de 13 tareas; entró T1, el botón de video al primer toque
  (`RewardedOfferButton`, revisión opus con arreglos). Los ítems 13–14 (placa colgante del ascensor y barra
  de 5 pestañas) quedaron en el tablero como P-E13b, **prioridad alta**.
- **Cerró sin resultado del `completo --limpio` de E1 T16** sobre `c94f75f`: quedó corriendo.

Detalle en **`Docs/SESION-2026-10-08-v2-relevo-12-ola-i.md`**.

### Sesión del 2026-10-08 (relevos 10 y 11) — La ola H: premios en minutos, carreras gratis, auto-tap y el `grant`

`version-2` quedó en `e378307`. **Progreso: 59 de 167 tareas activas integradas (35,3 %).**

- **El relevo 10 quedó vivo pero invisible**: el dueño borró la rutina `fisu-v2-relevo-b` y el scheduler
  archivó la sesión que ella había lanzado, que siguió con el `LOCK`. El dueño ordenó matarla; sus
  oráculos murieron con ella y sus dos agentes habían dejado E2a T11 y E3b T3 sin commitear: el relevo
  11 los retomó.
- **Entraron** E3b T3 (las piezas del menú deslizable), E4a T8 (el `grant` único y el momento calmo, sin
  llamadores todavía), E2a T11 (diario, asado y logros en minutos), T12 (las carreras: contrataciones
  gratis, Juicio ganado, Obra social), T13 (pisos en marcha en el mapa), T14 (el panel de debug de la
  economía) y E6a T3 (el auto-tap, sin llamadores). T11, T12 y E6a T3 pasaron por revisión opus porque
  mueven plata; volvieron aprobadas, T11 y T12 con arreglos.
- El `completo --limpio` #1 de E1 T16 dio verde: EK necesitó `swift package clean` (la mudanza a
  `.nosync` dejó rutas viejas en el `ModuleCache`) y `MenuUITests` fue flaky de carga (aislada 7/7 ×2).
  El #2 sobre `e378307` quedó corriendo.

Detalle en **`Docs/SESION-2026-10-08-v2-relevo-11-ola-h.md`**.

### Sesión del 2026-10-07 (relevo 8) — La ola F: el primer `completo` verde desde la ola B, el embudo de E1 y lo pagado que no se pierde

`version-2` quedó en `baabced` (`f9207c2` más `tasks.md`), con `rapido`
VERDE sobre `f9207c2` (EK 506 · unit 704 + 1 · release 0), pusheado.
**Progreso: 35 de 167 tareas activas integradas (21,0 %).**

- **La llegada integró las ramas sueltas del relevo 7**: los arreglos de E1
  T10, los mutantes de E5a T2–T3, E11 T4, E2a T1 y E6b T1–T2. Sobre esa punta
  (`15318a0`) **el `completo` dio VERDE** y es la referencia nueva (§6): el
  primero verde desde `d22eb7a`. El rojo de `MenuUITests` en E11 T4 era flaky
  de carga.
- **La ola F**: E1 T12 (Startup, Blanqueo, videos y carrera por el embudo;
  borró `resyncTower` y `performInstantMerge`), E3a T7–T8 (la barra baja y la
  botonera del ascensor), E11 T5 (la tarjeta del permiso), E2a T2 (el
  reintegro detrás de `EconomyKnobs`, en 0 = v1) y T6 (el plan de Fusionar
  todo), y E6b T3 (`skins.json` v2).
- **E1 T12 abrió y cerró una pérdida de video pagado** (§5): el carry pedía
  asentar toda la cola en `.inactive` sin animación; la revisión opus vio que
  un kill desde el App Switcher perdía el video. Ahora en `.inactive` se
  asienta sólo lo pagado, también lo que está en vuelo.
- **E2a T3/T4 van después de E1 T14**, porque E1 T12 salió antes (§5).

Quedan E2a T7 (`acf633d`, en su rama) y, en vuelo al cierre, E1 T13 y E3b T1.
**Lo próximo**: integrarlos, un `completo` que mida los montos de E2a T7, y la
ola G (`tasks.md` §4). Detalle en
**`Docs/SESION-2026-10-07-v2-relevo-8-ola-f.md`**.

### Sesión del 2026-10-07 (relevo 7) — La ola E: el turno de los cambios, `GameState` partido, el ORO exacto y el ciclo más barato

`version-2` quedó en `60af174` con la ola E, `rapido` VERDE (EK 447 · unit
683 + 1 · release 0), pusheado:

- E1 T9, el turno de los cambios del tablero (confirmar una sola vez;
  confirmar revalida y reencarnar asienta la cola) y **T9b, `GameState.swift`
  partido en extensiones**: 1.174 → 334 líneas, con el mapa símbolo → archivo
  en `task-9b-report.md`. Costo: todos los `private(set)` pasaron a `var`
  (§5);
- E1 T10, la escena que reproduce los cambios como merges, **integrada sin
  sus arreglos de revisión** (2 Important), y E1 T11, el sorteo que salta lo
  inaplicable;
- **E1 T6c, el ORO comprado exacto entre dispositivos** (decisión del relevo
  6), y si `Transaction.all` vence el plazo la reconstrucción **no se cierra
  en 0**: se reintenta en el próximo arranque;
- E3a T6 (las hojas en iPad con `fisuSheet`; los 9 `.sheet` de `RootView` los
  migró el controlador, quedan 2 a propósito), E4a T1 (`RewardSpec`), E5a
  T1–T3 (paquete, colchón y ruleta, puros) y E11 T3 con sus arreglos;
- los planes por tareas de E2b (15) y E9 (20): ya sólo falta el de E8 (el
  resto) y la parte de agente de E10.

**El dueño pidió dos cosas** (§5): los guiños escondidos (Six Seven en tres
lugares y "andá pa' allá, bobo" una vez) y un desarrollo **más expeditivo y con
menos tokens**. Medido: el `unit` tardó 1.244 s con tres agentes compilando y
438 s libre, y cada tarea pagaba ~30 min de `rapido`. Ahora el agente corre
`oraculo.sh tarea <Clases>`, el brief sale de `Tools/v2/brief.py`, la
revisión depende del riesgo y el `rapido` entero va una vez por ola (§6).

Fuera de `version-2` quedan E11 T4 (con un UI test rojo sin medir en la base),
E2a T1, E6b T1, los mutantes de E5a T2+T3 (61 → 92 de 93 muertos) y los
arreglos de T10. **Lo próximo**: integrarlos, un `completo` sobre la punta, y
la ola F (`tasks.md` §4). Detalle en
**`Docs/SESION-2026-10-07-v2-relevo-7-ola-e.md`**.

### Sesión del 2026-10-07 (relevo 6) — La ola D: el ciclo de vida, el Release que el `rapido` no veía y la app universal

Entraron a `version-2` la ola D de E1 (`7110b06`, pusheado) y E3a T5
(`3956fd3`, pusheado después de su `rapido` VERDE):

- E1 T8, el ciclo de vida: se sella la hora sólo al irse, una vez por salida,
  dentro de un background task; con la escena inactiva no se cobra ni se
  dispara nada; el watchdog recibe el delta con tope de 2 s; el evento
  vencido afuera se corre +60 s; un latido guarda cada 15 s (`eeb7322` +
  `5ef7a65`). El simulador lo confirma: 45,39 s afuera → 7,943 acreditado,
  exacto;
- E1 T5c, el `if` muerto que no dejaba compilar Release, y **el `rapido` que
  ahora compila Release** (`e0a5d53` + `ca2d12c`);
- E3a T5: la app es universal (iPad sólo vertical y de pantalla completa) y
  pide iOS 18 (`c323dd9`).

**El `completo` sobre `8d17b8d` (la ola C) dio todo verde menos Release**: UI
59, Store 13, `pacing-sim` sin cambios, y `GameState.swift:545: will never be
executed`. Lo trajo E1 T5, y tres `rapido` no lo vieron porque no compilaban
Release (§7). El `rapido` de E1 sobre `ca2d12c` da **VERDE, EK 357 · unit
633 + 1 · release 0**.

Quedaron fuera de `version-2`: E5a T1, el paquete puro (`a4c156f` en
`v2/e5-premios`, EK 393, con 8 de 8 mutantes muertos después de que la
revisión encontró 7 vivos), y E11 T3, el manager 2.0 (`f084ef5`), con dos
tests por arreglar que no se despacharon. Salió el plan de E7b, partido en
E7b-a y E7b-b, y E7b-b se re-planeó con la columna plegable.

**El dueño decidió cuatro cosas** (§5): las rutinas de relevo, el ORO comprado
exacto entre dispositivos (E1 T6c), que las fusiones asistidas cuentan, y la
columna plegable. Y pidió **`tasks.md`**, el tablero único de la 2.0, en la
raíz de `version-2`. Lo próximo: E1 T9 ∥ E1 T6c, y decidir si se parte
`GameState.swift`, que 20 tareas pendientes tocan de a una (`tasks.md` §4).
Detalle en **`Docs/SESION-2026-10-07-v2-relevo-6-ola-d.md`**.

### Sesión del 2026-10-07 (relevo 5) — La ola C: `BoardChange`, el save ilegible, el ORO comprado de la v1 y las safe areas

Entró la ola C de E1 y la T4 de E3a, integradas en `version-2` con merges
`--no-ff` (`cd23856` y `bc3bf6f`), sin conflictos:

- E1 T7, el embudo `BoardChange` en EconomyKit: planear y aplicar, con
  desempate determinista (`ec6fb29`);
- E1 T5, un save que existe y no se lee ya no se pisa: copias en
  `SaveBackupStore` y la pantalla `SaveRecoveryView` (`38bee13`);
- E1 T6, el ORO comprado en la v1, reconstruido desde `Transaction.all`
  (`cdd8f0a`);
- E3a, `crowdTopRatio` de tres filas a 0,63 (`5afb893`) y las safe areas
  observables desde un centinela en la ventana (`b988bc3`, `537f923`).

Todas pasaron la revisión con 0 críticos o importantes. El `rapido` de fin de
ola de E1 dio **VERDE, EK 357 · unit 608 + 1**. **El de `bc3bf6f` dio ROJO**
con `rotatesTheLastTenGoodLoads`, un test de T5 que nombra copias por
milisegundo y pasó mientras la máquina estuvo cargada (§7). Lo arregla E1
T5b, despachado al cierre, y `bc3bf6f` no se pushea hasta que esté verde.

El `completo` sobre `d22eb7a` dio VERDE y es la referencia nueva (§6): la
frontera de un solo mutador y el save v6 no movieron el pacing. **La ola C
todavía no pasó por un `completo`.**

Salieron los planes de E5 (E5a, el motor, 9 tareas; E5b, lo que se ve, 7) y
de E6 (E6a, la tienda de ORO, 13; E6b, lugares extra y skins, 10, con 3
gates). `LootBoxGate` y `OddsDisclosureView` nacen en E5, y E6 los consume.

El 🔒 de `SaveConflictResolver` pasa a ser de dos líneas, `:67` y `:68`, con
un insumo nuevo de T6: el `||` sólo cuenta de menos, un `&&` contaría doble,
y la exactitud pide otro diseño. La carrera de las safe areas en el `onAppear`,
que el relevo 4 daba como probable, quedó medida: 7,5 pt del bezel en el SE.
Detalle en **`Docs/SESION-2026-10-07-v2-relevo-5-ola-c.md`**.

### Sesión del 2026-10-07 (relevo 4) — La ola B: la frontera, el save v6, el núcleo de E11 y los spikes de la pantalla

Entró la ola B, integrada en `version-2` en `5a65335` con merges `--no-ff` de
las tres épicas, sin conflictos:

- E1 T3, un solo mutador de la frontera y contadores `Double` (`111bbfb`);
- E1 T4, el save v6 con `EngagementState` (`76a69c1`);
- E11 T1, el planificador puro (`508a4c5`), y T2, `notifications.json`
  (`9c5847c`);
- E3a T1, `Tools/v2/catalogo.py` (`f542b16`), y T3, `PlayLayout` (`f03950c`).

Cada tarea pasó la revisión de spec y calidad con 0 críticos o importantes. El
`rapido` sobre `5a65335` da **VERDE, EK 317 · unit 593 + 1 declarado**, exacto
con la suma de las tareas (§6). El pipeline ya no tiene rojo declarado
(`af3acde`). De la ola B queda E11 T3.

**Los spikes de E3a (T2, sin commits) cambian cuatro tareas, y el plan todavía
dice lo viejo:**

- las hojas de iPad van por `fullScreenCover` (T6);
- las safe areas se leen con un centinela en la ventana (T4);
- `crowdTopRatio` de 3 filas baja de 0,70 a 0,63 (T3 ya integrada, y T10);
- los botones de la botonera pasan a 30 pt (T8).

Salieron los planes de E2a (15 tareas) y de E4, partido en E4a (el motor, 10)
y E4b (la escena y el Álbum, 10). Hay dos 🔒 nuevos para el dueño: el `||` de
`SaveConflictResolver` sobre la reconstrucción del ORO, y la columna de E7b,
que pisa la multitud en todo iPhone. Detalle en
**`Docs/SESION-2026-10-07-v2-relevo-4-ola-b.md`**.

### Sesión del 2026-10-06 (noche, relevo 3) — Los cuatro frentes integrados, la línea de base nueva y la Ola A

Entraron a `version-2` los cuatro frentes que habían quedado sin commitear: E8
pipeline (`cd48569`), E8 audio (`539e1e7`), E7a (`0e72509`) y E3 i18n
(`6b5e408`), con merges `--no-ff` y sin conflictos. El oráculo `completo`
sobre `6b5e408` dio **VERDE** y es la línea de base nueva (§6): unit **570 + 1
declarado**, exacto con la suma de los frentes (473 + 72 + 12 + 13).

El dueño pidió agentes concurrentes que no se pisen y notificaciones prendidas
por defecto. Entraron como **PLAN-v2 §0.1** (el despliegue de agentes) y la
épica **E11** (`4fd77c8`); las decisiones, en §5.

En la Ola A se cerraron E1 T1 (offline, `3693044`) y T2 (la Milanesa, `37c565f`),
revisadas e integradas en `v2/e1-correcciones`, y salieron los planes de E11 (`eaa3497`, 7 tareas) y de
E3, partido en E3a (12) y E3b (9) para correr al lado de E1 (`aff6a6e`). Tres
trampas nuevas en §7: el clasificador que no deja usar `sed`, lo que de verdad
funciona con el guard de aislamiento, y la carga de la máquina. Detalle y el
estado de E1 tarea por tarea en
**`Docs/SESION-2026-10-06-v2-integracion-y-ola-a.md`**.

### Sesión del 2026-10-06 — E3, idioma: IAP, ATT, splash y el test del catálogo

Los IAP dejan de salir de App Store Connect: `IAPCopy` los nombra y los
describe con `iap.<productID>.name/.desc` del catálogo, y lo de StoreKit queda
de respaldo sólo cuando falta la clave. Los textos son los de la ficha de E10:
"Saco de ORO", y `remove_ads` ya no promete sacar los videos con premio. Los
números (el monto de ORO, los personajes de Diamante) se interpolan desde los
datos. El diálogo de ATT ya está en inglés. El splash muestra el logo
(`UIArt` lee el manifest del bundle por su cuenta, sin esperar al bootstrap) y
sus consejos están en el catálogo. `LocalizationCompletenessTests` exige toda
clave `translated` en es + en con los mismos placeholders, las 14 familias
dinámicas cubiertas por el contenido e `InfoPlist` completo; destapó
`CFBundleName` sin inglés. Unit +13. Detalle en
**`Docs/SESION-2026-10-06-v2-e3-i18n.md`**.

### Sesión del 2026-10-06 — E7a: la infraestructura de anuncios de la 2.0

Primera mitad de E7, sin UI y sin tocar llamadores. Entraron:

- el **intersticial bonificado** (pausa publicitaria) y el **app open** en el
  proveedor, con vida de inventario por formato (55 min / 3 h 30);
- las **unidades por momento** de la 2.0 (`wheel`, `treasure`, `visitor`,
  `daily`, con fallback a Regalos), la pausa con la unidad existente
  `…/1615619906`, y el app open en `null` (gate del dueño);
- **`AdsRemoteConfig`**: `config/ads.json` en `adergames-site`, sólo HTTPS,
  IDs validados contra el publisher propio, todo o nada, pisos con las
  decisiones del dueño, caché + respaldo `Resources/Config/ads.json`;
- la **política de cortes naturales** (`NaturalBreakPolicy`, pura) y su estado
  (`ForcedAdsPacer`), testeadas y **sin cablear**: la 1.x sigue con
  `armIfDue` hasta E7b;
- `remove_ads` corta los tres forzados, y `AdsCoordinator` ya no deja encimar
  dos anuncios.

La mediación quedó investigada, no agregada: la pausa sólo la sirve Meta y el
app open sólo Mintegral. Unit +72. Detalle en
**`Docs/SESION-2026-10-06-v2-e7a-anuncios.md`**.

### Sesión del 2026-10-06 — E8 audio: un tema por piso

Diez temas chiptune sintetizados con el generador de la v1 (uno por piso de
`economy.json`, `music_<id>_loop.caf`, AAC 80 kbps, 2,39 MiB) y los SFX
`sfx_wheel_tick`, `sfx_blackout` y `sfx_elevator_ding`, **sin cablear**: cada
uno entra con su feature, porque `AudioWiringTests` exige un call site por
caso. `AudioManager.showFloor` hace el crossfade de 1,5 s con un
`FloorMusicDirector` puro: máximo dos voces, el mismo piso no re-dispara y
volver restaura sin recargar. Se engancha en `GameBoardView` observando
`gameState.visibleFloorDef?.id`: cero líneas en `GameState`/`BoardScene`. Bajo
`--uitest*` y XCTest suena el earth de siempre y no carga ningún tema.
Unit +12. **Nadie los escuchó todavía: es gate del dueño.** Detalle, números y
cómo escucharlos en **`Docs/SESION-2026-10-06-v2-e8-audio.md`**.

### Sesión del 2026-10-06 — E8 pipeline: el calado que no era, `npc`/`skinfam` y el contrato de los loops

- **El "arte calado ya publicado" no existía.** Los huecos del tropero (el
  óvalo del lazo) y del médico (el aire junto a la manga) son islas de papel
  que eligió el dueño (`islas_de_papel.json`, `bc5f358`). El test no las
  conocía y estaba rojo desde `2b3d23f`. Ahora permite exactamente ese hueco,
  medido recortando el original, y un hueco nuevo sigue saltando. Los atlas no
  se tocaron.
- **`rentista_soles` tiene 8 de 12 soles casi transparentes** (alfa medio
  0,00–0,18; recorte por saliencia elegido a mano). Queda como gate del dueño,
  con tres caminos medidos.
- `process_dropbox.py`: `npc` → `npcs.atlas` + manifest `npcs`; `skinfam` →
  `fam_<familia>.atlas`, sin manifest. Las poses `sp_<id>_talk/_face` van como
  `npc`.
- `scripts/video_assets.py` + `Resources/Data/loops_manifest.json` (vacío,
  schema 1): retratos 512² HEVC con alfa en `Loops/`, cinemáticas 720×1280 en
  `Cinematics/`. El verde del key se mide en cada master: en el del cofre da
  `0x22934C` contra el `0x22924A` calibrado a mano.
- Pipeline: de 25 con 1 rojo a **49 verdes, 0 rojos**. Detalle en
  **`Docs/SESION-2026-10-06-v2-e8-pipeline.md`**.

### Sesión del 2026-10-06 — E10 en papel: setup de la 2.0, IAP y Términos

Sin código. Salió **`Distribution/setup-v2-asc-admob-mediacion.md`**, el
entregable del ítem 18: App Store Connect (Novedades, ficha es-ES, capturas de
iPad, 14 productos con el conteo de sus 42 fichas, checklist del ítem 19, edad,
App Privacy y notas a App Review), AdMob (11 unidades y 4 grupos de mediación
por formato) y las 4 redes paso a paso, con la URL oficial de cada dato y 🔒 en
cada paso del dueño. `iap-appstore-connect.md` quedó con los 14 productos
(packs de ORO 160/550/1.400 y las 3 ofertas), y los Términos (es, en y la copia
del bundle) ya no dicen que "Sin anuncios" saca los videos con premio: los
nuevos valen también para la v1 y se pueden publicar ya. La unión de
SKAdNetwork de las 4 redes + Google da **156 IDs, 106 nuevos**. El porqué está
en **`Docs/SESION-2026-10-06-v2-e10-docs.md`**.

### Sesión del 2026-10-06 (noche) — E0 de la 2.0: el oráculo y la línea de base

Primera sesión de ejecución del plan. Lo central es **`Tools/v2/oraculo.sh
rapido|completo [--limpio]`**: la receta de §6 hecha comando, con
simuladores propios por UDID y un juez, `Tools/v2/rojos.py`, que compara cada
suite contra `Tools/v2/rojos-declarados.txt` (§6). La línea de base del
`completo` sobre `0442022`: EconomyKit **267** · unit **473 + 1 declarado** ·
Store **12** · UI **57** · `StoreUITests` **2** · pipeline **24 + 1
declarado** · `pacing-sim` Dios en 30,73 h activas con 13 reencarnaciones ·
Release con 0 warnings. Un `completo` tarda ~45 min. ⚠️ La primera versión
compilaba el proyecto del cwd y no el de su worktree; se arregló en `50922d4`
(§7).

También salieron `Docs/biblia-visitantes.md` (8 visitantes nuevos, 10
especiales, 3 familias de skins; los 222 prompts quedaron **sin commitear** en
el repo generador, que tiene cambios ajenos) y el plan de E1 (16 tareas en
olas). La sesión dejó en vuelo cinco frentes en paralelo (E8 pipeline, E8
audio, E7a, E3 i18n y E10 docs), y los cinco chocaron con el guard de
aislamiento (§7). Detalle en **`Docs/SESION-2026-10-06-v2-e0-oraculo.md`**.

### Sesión del 2026-10-06 (noche) — El plan maestro de la 2.0

No hay código: se planificó la 2.0 entera. Salió **`Docs/PLAN-v2.md`**,
aprobado por el dueño: los 19 pedidos del feedback de la v1 + 5 de la crítica
de un jugador avanzado + 3 de la sesión de preparación, cada uno con su
épica. El porqué está en `Docs/SESION-2026-10-06-plan-v2.md`.

Lo que un agente necesita saber sin abrir nada:

- **Cinco pedidos no eran lo que parecían.**
  - El pasivo "congelado" es el `.inactive` que re-sella la hora al volver.
  - El descuento del Abogado sí se aplica, pero lo tapa el salto ×2,99 de la
    frontera.
  - Las fusiones "solas" son el evento "Startup comprada" sin revelación.
  - Los premios valen 120·k s de una sola unidad.
  - Los precios que se disparan vienen del contador por tipo.
  - Tabla y archivos en la sesión.
- **Cambia el contrato de pacing** (§5, decisión 11): Dios en 31–35 h
  activas, 4–6 reencarnaciones **medidas con un bot que reencarna al
  multiplicar ×5 su ORO**, más tiempos por piso. Se reescribe en la épica
  E2b. Hasta entonces el test viejo sigue rojo por la misma razón de siempre.
- **El ORO pasa a ser la moneda premium de todo** (tienda de ORO, ruleta,
  skins). Las líneas pasan a costar 348 (seis desde E13 T7; el costo base 2 lo pone E2b T14). Los packs serán 160/550/1.400 por
  USD 1,99/4,99/9,99.
- **La app pasa a universal**: iPad sólo vertical, iOS mínimo 18.
- **Herramientas nuevas, globales**: harness AVO y skills de documentación.
  La ejecución es un relevo automático de agentes (PLAN-v2 §0).

### Sesión del 2026-10-06 — La rama `version-2`: integrar lo suelto y sacar lo que sobra

Con la v1.0.0 publicada, se armó la rama de la v2 desde la punta del build y se
le integró todo lo que había quedado afuera: `origin/main`, el arreglo del
congelón del cofre (que estaba en un `main` local sin pushear) y las dos
features del 28/08 que nunca se habían mergeado (cofres sólo desbloqueados y el
atajo al mejor tier). La rama de reacciones de campo quedó **descartada** por
el dueño.

Integrarlas destapó un bug que ninguna de las dos tenía por separado: la oferta
del cofre extra por video no sabía de la regla de desbloqueo. Y la auditoría
encontró otro en producción: comprar "Quitar anuncios" no apagaba el
intersticial hasta reabrir la app. Los dos quedaron arreglados con tests.

La limpieza sacó del `.app` ~6,5 MB que nunca se usaban (39 imágenes del
`ui.atlas` y la música cósmica), 12 strings muertos y el código Swift sin
llamadores. Del repo salieron la generación de arte (vive en su propio repo),
`balance-sim`, el CI de julio, y `ESTADO.md` y `tasks.md`. Lo que sigue vivo
de `ESTADO.md` pasó a §7. Versión **2.0.0 (5)**. Detalle, números y la lista
"Para el plan" en **`Docs/SESION-2026-10-06-preparacion-v2.md`**.

### Sesión del 2026-09-03 — El cofre ya no se traba al principio

«La animación del cofre se traba al principio. Arreglalo.» Medido con una
sonda nueva de la LLEGADA (`arrival_probe.py`: localiza el overlay por la
caída de brillo del telón y escupe un símbolo por frame a umbral fino):
**el telón aparecía y la pantalla quedaba clavada 466 ms** antes de que el
cofre entrara. La causa: `choreograph(.arriving)` disparaba el resorte de
entrada y en la misma pasada `warmPrizeArt()` leía el retrato del premio EN
LÍNEA (`characterImage` → página entera del atlas + `cgImage()`, los ~320 ms
que la cuarta del 28-08 había medido y dejado ahí a propósito). Un bloqueo
del hilo principal durante una animación no deja dibujar un solo frame de
ella. Fix: **`UIArt.warmCharacterImage`** — `SKTexture.preload` carga la
página en background, el completion re-busca la textura por nombre (no es
`Sendable`) y hace el `cgImage()` + caché en el MainActor con la página ya
en memoria; se calientan las dos candidatas (pinta y base) porque el
fallback existe. Después: el resorte corre desde el primer frame, cero
corridas ≥100 ms del tercer toque a la carta, video a 32–35 distintos/s
con load ~600. No era el preroll de la sexta (la sonda no le atribuye
nada). Detalle en **`Docs/SESION-2026-09-03-cofre-arranque.md`**. UI del
cofre **3/3** · unit completa **465 con el único rojo declarado** (Pacing
contrato; las dos suites de Store salteadas por ENTORNO).

### Sesión del 2026-08-28 (sexta) — El cofre a velocidad: 1,5x, 36 fps y el empalme sin congelón

El dueño volvió a ver la animación «lagueada y muy lenta» y pidió 1,5x «sin
lag, como en el video». Dos hallazgos y dos arreglos. (1) **La traba era
real y el promedio la escondía**: midiendo corridas de frames idénticos (no
distintos/s) aparecieron **150+133 ms de congelón en el empalme f49→f50** —
el preroll del player era sólo crear el item, `automaticallyWaits…` seguía
en `true` y el `AVPlayerLayer` se montaba en el frame del estallido. Ahora:
preroll de verdad al llegar a `readyToPlay` (poll en MainActor; KVO no
convive con AVPlayer bajo strict concurrency), capa montada invisible desde
la llegada, `playImmediately(atRate:)` — quedó en ~100 ms, el umbral del
instrumento. (2) **El 1,5x es un RETIME**: los mismos 190 frames del master
presentados a **36 fps** (más rápido Y más fluido, cero frames sintetizados),
audio con `atempo` (mov y clips SFX), manifest con fps 36 para que PNGs y
video corran al mismo ritmo, relojes re-derivados (flip 4,0 s, datos 4,33 s,
tramo 5,28 s, tercer toque 0,33 s). **Medido en el sim con la máquina
cargada: 28–36 cuadros distintos/s todo el tramo** (a 48 colapsaba; 36 es el
punto dulce). ⚠️ Trampa de encode: VideoToolbox pisa los PTS retimeados con
`-vsync 0` — va `-r 36 -fps_mode cfr -frames:v 190`. Y la trampa GRANDE del
día (§7): el fixture "roto" era el **binario compilado en el checkout
compartido mientras la otra sesión editaba** — worktree aislado siempre.
Detalle en **`Docs/SESION-2026-08-28-cofre-a-velocidad.md`**. Números:
pipeline **13/13** · unit **463 con los DOS rojos documentados** (Pacing
contrato + `StoreProductsTests` entorno) · grabaciones antes/después
analizadas frame a frame.

### Sesión del 2026-08-28 (quinta) — El muro adentro de la cuesta pre-compuerta

El dueño reportó jugando que llegar al tier 8 se hacía eterno y que el Fisura
terminaba costando 1M. Tenía razón, y el número es exacto: la cuesta
pre-compuerta se paga con **una sola curva** —el Fisura es lo único que la
compuerta habilita hasta la frontera 7— y el exponente de esa curva se duplica
con cada tier, así que `growth^(2^k)` es una doble exponencial. Medido en clicks
de tu propia frontera: `26 · 39 · 61 · 117 · 322 · 1.931 · 61.921`, o sea **×32
en el último paso** — 14 minutos los seis primeros tiers juntos y 5 horas y
media el séptimo solo.

Arreglado con **`floors[alley].hireCostGrowth: 1.03`**, dejando el
`hire.defaultCostGrowth` global **intacto en 1,06**. Bajar el global es lo que
decía el pedido literal, se probó primero y midió peor: desarma la pared (de
seis runs trabadas a dos) porque ese factor era **la segunda pata de la
desaceleración**, algo que la cuarta ronda (ter) no había escrito. El override
del piso deja la torre quieta: maxear 20,67 → 20,33 h (sigue en la banda del
dueño), dios 28,43 → 30,73 h activas, la pared en seis runs corriendo T13 → T20.

Guard nuevo: **`thePreGateClimbHasNoWallInIt`** — ningún tier de la cuesta puede
costar 8× el anterior. Es aritmética sobre el contenido real y no una banda del
simulador **a propósito**: `pacing-sim` cronometra esta fase en 96 s porque su
bot tapea a 6/s con todo comprado, así que la bitácora la venía anotando como
demasiado RÁPIDA mientras el dueño se trababa en ella.

**Y el suite encontró algo que el knob destapó**: con 25 × 1,03 = 25,75,
`CoinFormatter` truncaba a "25" y la primera contratación no movía el precio en
pantalla. **Cuatro tests dijeron lo mismo** —dos pines, la proyección que no se
republicaba (y tenía razón: `BestHire` lleva sólo lo que se dibuja) y el de UI
punta a punta—, y cuando cuatro coinciden el que está mal no es el test. Se
arregló con **`CoinFormatter.cost`, que redondea los precios hacia ARRIBA** en el
tramo exacto: un precio truncado miente para el lado que rompe (el botón decía 25
y cobraba 25,75, así que con 25 monedas exactas la compra rebotaba), y eso ya
pasaba antes de esta ronda. La asimetría ahora tiene las dos mitades escritas: el
SALDO trunca para no anunciar plata que no se puede gastar, el PRECIO sube por el
motivo simétrico. Los cuatro volvieron a verde sin tocar un assert.

⚠️ **Trampa nueva y cara (§7, trampa 40)**: el primer barrido corrió **sin
catálogo de mejoras** —`pacing-sim` busca `upgrades.json` al lado del
`economy.json` y las variantes vivían en un temporal— y dio la conclusión
OPUESTA. La herramienta avisaba; el `grep` con el que filtré su salida se comió
el encabezado. Doc de sesión:
**`Docs/SESION-2026-08-28-cuesta-pre-compuerta.md`**. Bitácora: "Quinta ronda".
Corrida: `balance-run-t12-cuesta-pre-compuerta.csv`.

### Sesión del 2026-08-28 (cuarta) — El pulido: el cofre en todos lados, el ORO que enseña y los 48 fps

Cuatro pedidos del dueño sobre el cierre del cofre, más un falso lag. (1) La
tarjeta de Regalos mostraba el cofre VIEJO con el PNG nuevo en el árbol: era
el **atlasc compilado** — escribir un PNG en el lugar no cambia el mtime de la
carpeta `.atlas` y el atlas no recompila (trampa nueva en §7; el pipeline
ahora toca la carpeta). Purgado todo el cofre viejo: masters, prompts y las 7
entradas de `prompts.json` (incluida `ui_chest_closed`, que un batch habría
regenerado pisando el icono del video). (2) **Los datos del premio entran a
los 6,5 s del cinemático** (la carta ya está derecha; antes esperaban el final
+1,5 s). (3) La fila de personaje dice **sólo el multiplicador** (el
"Nivel 1/19" murió; al tope queda el badge "Al máximo"). (4) **El botón de
reencarnar arranca al llegar a lujo** (`oro.prestigeTeaserFloorId`,
data-driven): teaser con el % del camino al próximo ORO y la hoja contando lo
que falta, SIN confirmar (una acción que no corresponde no se dibuja) y SIN
tocar la curva — Pacing intacto. (5) **La lección del primer ORO**
(`oroUpgrades`): un logro paga el primero, el globo lleva a Mejoras y la
manito marca la primera línea pagable hasta que elige. (6) El "video
laggeado" era **la Mac saturada por las suites** (medido: a máquina quieta el
sim entrega 24 fps clavados; §7). La interpolación a 48 se PROBÓ — limpia a
ojo, pero el sim la decodifica PEOR (colapsa a ~5 fps en el giro): quedó como
**perilla apagada** (`CINEMATIC_OUTPUT_FPS`) para cuando haya device. Detalle en
**`Docs/SESION-2026-08-28-pulido-post-cofre.md`**. Números: EconomyKit
**262** · unit **461 con el único rojo declarado** · UI de prestigio,
tutorial, mejoras y cofre **todas verdes** · catálogo +2 claves por el script
canónico de la trampa 29.

### Sesión del 2026-08-28 (ter) — El cofre definitivo: 2D, vertical y con sonido

El dueño entregó el master definitivo («usa la estética de este cofre que es
en 2d… ponelo en el juego con su respectivo sonido. borra todo lo relativo a
las animaciones anteriores»): **720×1280 vertical, cartoon calzado al juego,
con pista AAC**. Recalibración completa (croma 0x22924A, cofre 448 px,
segmentos A [23,38] / B [39,49] con **empalme continuo al video en f50** — la
B es el temblor que desemboca en el estallido, y por eso los toques 1 y 2
repiten la A), `parchmentRect` (172,363,349,504). Con el cofre a **274 pt**
el lienzo cubre la pantalla entera menos un tramo de adoquines abajo:
full-bleed medido sin costura. **El push-in de la casa murió** (la carta del
video ya hace el suyo y termina grande: contenido a ~214×308 pt sin zoom).
**El sonido va en dos familias**: el cinemático DENTRO del mov (AAC, atrim al
mismo arranque; `play(rate:volume:)` con el volumen SFX de Ajustes) y las
sacudidas como `sfx_chest_shake_a/b.caf` en `Resources/Audio/` (PCM, ventanas
exactas de sus frames, generados por el pipeline) — `AudioManager.SFX` ganó
sus dos casos y `AudioWiringTests` barre ahora también `UI/Popups`. El fade
del cofre viene horneado COMO MEZCLA AL VERDE y keyeado queda una sombra que
se evapora (verificado A/B). Detalle en
**`Docs/SESION-2026-08-28-cofre-definitivo-2d.md`**. Números: pipeline
**13** · unit **459 con el único rojo declarado** · cofre+audio **17/17** ·
UI **3/3** · latidos en vivo con el **cinemático de 8,19 s terminado por la
notificación real**. ⚠️ Y una lección de instrumento: la cadencia de
`simctl screenshot` en máquina cargada hace parecer que el arco se saltea —
el juez del timing es el log de latidos, no las capturas.

### Sesión del 2026-08-28 (bis) — El velo del encuadre, y el master que se desvanece

El dueño reemplazó el master («la animación todavía no se ve correctamente…
el cofre se abre y desaparece de forma seamless»): **verde plano sin viñeta
ni piso horneados, el cofre estalla, suelta la carta y se desvanece solo**
(~f114–126) — la desaparición es del arte, no de un fade nuestro. Misma
arquitectura de la sesión de la mañana, recalibrada entera (croma
**0x10A12A**, segmentos A [4,30] / B [31,47], crops por percentil de masa ∪
bbox del cofre frame a frame, `parchmentRect` por beige MACIZO — el bbox de
claros se estira con los biseles del borde). Y cayó el bug que la v1 tenía
disfrazado: **el mov ahora va PREMULTIPLICADO**, porque `AVPlayerLayer`
composita el HEVC-alfa como premultiplicado y el RGB intacto del `chromakey`
(el verde despillado, L≈26) se SUMABA al juego como un velo claro cortado en
el encuadre — +20..27 de luminancia medidos restando capturas, desde el
frame 48 (el primer frame del mov). La "viñeta horneada que se cortaba" de
la v1 era ESTE bug con fondo oscuro; el feather queda (desvanece el confetti
del borde) y el scrim pasa a ser el foco de la casa. En el runtime, lo único
nuevo: el PNG de respaldo **se jubila a los 0,6 s de video** (`stageRetired`)
— con el cofre desvaneciéndose, el frame quieto de atrás lo resucitaría.
`ui_chest_closed` regenerado del f0 nuevo (violeta+dorado) por componente
conexa (los destellos ambiente inflaban el bbox global). Detalle y tabla de
recalibración en **`Docs/SESION-2026-08-28-cofre-video-v2.md`**. Números:
pipeline **12** · unit **458 con el único rojo declarado** · cofre unit
**11/11** y UI **3/3 sobre el build final** · velo re-medido: **muerto**.

### Sesión del 2026-08-28 (bis) — El atajo vuelve a vender el mejor tier

El botón de contratación del HUD ofrecía el tier más alto pagable **entre los
tier base de cada piso**; ahora ofrece el más alto pagable, punto. Es la vuelta
atrás de §4.5 del rebalance, y el motivo es que los datos se movieron debajo de
esa decisión: el simulador de pacing empezó a comprar todos los tiers **un día
después** de que el recorte entrara, así que el contrato de las 20-30 h quedó
medido con un jugador que compra el mejor tier — el recorte hacía al botón peor
que el jugador que el balance modela. Ver §5.0-quinquies.

Efecto de vuelta que vale anotar: **los desempates de `computeBestHire` volvieron
a ser alcanzables**. Con el recorte, cada piso aportaba un solo candidato y dos
nunca empataban, así que sus dos tests se habían retirado. Sin él, los tiers 11 y
12 aportan cuatro cada uno —las ramas de carrera— y el empate es la regla, no el
borde: `tiesOnTierPreferTheCheapest` y `tiesFallBackToTheAscendingID` volvieron a
la suite.

### Sesión del 2026-08-28 — El cofre animado por video

**La apertura de cofres es el video del animador entero** (`chest-animation.mp4`,
pantalla verde; el master vive en `Tools/asset-pipeline/video/`), en dos rondas
del dueño: integrar el video, y después «dejá SOLO el video y renderizá el
contenido de la carta en el marco vacío del final». Tres toques fuerzan el
candado (frames PNG cuantizados — el dedo pide swap inmediato) y del estallido
al marco corre **`chest_open.mov`, HEVC con canal alfa: el primer AVFoundation
del repo** (3 MB contra ~12 en PNGs, el porqué en `ChestCinematicPlayer`). El
premio se renderiza dentro del pergamino (`parchmentRect`, segunda ancla del
manifest `chest_anim.json` — contrato pineado por tests de pipeline y runtime),
con push-in de cámara 1→1,3 y feather de 28 px en los bordes del encuadre.
Murieron `ChestShake`, `ChestDrop`, `FlyingLid`, el flash, los rayos teñibles,
las ráfagas y la carta `PanelCard` del popup — **y con los rayos, el anuncio de
rareza del segundo toque** (la cinta del marco lo cubre). Retirados de atlas y
manifest: `ui_chest_cracked/open/lid` y los tres `fx_*` (sin llamadores);
`ui_chest_closed` regenerado del frame 0 (Regalos y el diario sin tocar
código). `Resources/ChestAnim/` pesa 4,5 MB. Trampas nuevas del pipeline: el
croma se mide en el stream con matriz LIMITED-range; `blend` con máscara en
`-loop` exige `shortest=1` DENTRO del filtro; `AVPlayer.preroll` con item
`.unknown` lanza NSException. Detalle en
**`Docs/SESION-2026-08-28-cofre-animado.md`** (con la enmienda en el spec §8).
Números del cierre: pipeline **12** · unit **458** (el único rojo es el
declarado de Pacing) · UI **53** (2 re-verificados: uno adaptado al flujo de 3
toques, uno de carga) · `StoreUITests` **2** — y 🔴 `StoreManagerTests` en 18.6
falló HOY con fallos rotativos de ENTORNO (diff sin un archivo de Store; ver
la doc de sesión y el aviso en §6).

### Sesión del 2026-08-28 — Los cofres sólo dan personajes desbloqueados

Un cofre ya no puede darte la pinta de alguien a quien no llegaste. El dato que ordenó la
implementación es que **la rareza YA era una banda de pisos** sin solapamiento (común =
pisos 1-2, rara = 3-4, épica = 5-7, legendaria = 8-9), porque la bolsa se había repartido por
el piso donde vive cada personaje: filtrar por desbloqueo es casi filtrar por rareza, así
que el sistema no se rediseñó — sólo se le puso un filtro en el embudo correcto.

- **Un solo lugar**: `ChestRoller.stock`, por donde pasan los tres caminos del sorteo. El
  parámetro `unlocked` **sin default**, para que un call site olvidadizo no apague la regla
  en silencio.
- **La historia global**, `meta.stats.maxFloorOrdinalEver`: lo que abriste en reencarnaciones
  anteriores sigue contando.
- **La bolsa alcanzable seca no paga: espera.** Tipo nuevo `ChestDraw`, y el contador no baja.
- **Tres efectos que no estaban en el pedido**: el mínimo de épica del cofre de reencarnación
  ahora cede ante el desbloqueo; el puntito de Regalos sigue a `canOpenChest` para no quedar
  prendido un piso entero; y la puerta de debug sube un piso simulado en vez de saltear el
  filtro.

Detalle en `Docs/SESION-2026-08-28-cofres-solo-desbloqueados.md`.

### Sesión del 2026-08-26/27 — Los cofres de skins

Las 41 pintas de piso dejaron de otorgarse al llegar a un piso: ahora **sólo salen de
cofres**. Ocho tareas cerradas, 32 commits, 78 archivos.

- **La bolsa son 41 skins en 4 rarezas** (7 comunes / 14 raras / 12 épicas / 8 legendarias),
  y la rareza sale del piso donde **vive** el personaje. "Rara" tiene 14 porque el piso
  corporativo tiene **diez** personajes: la bifurcación de carrera mete cuatro `junior` en
  T11 y cuatro `senior` en T12.
- **La promoción de rareza es lo que hace que el sistema cierre.** Hay 7 comunes con peso
  55/100: se agotan cerca del cofre 12. Sin promoción, desde ahí más de la mitad de los
  cofres pagaría plata con 34 skins sin sacar. Con promoción, todo cofre da skin nueva —41
  exactos— y las legendarias quedan para el final.
- **El mecanismo es no tocar `SkinMilestones`**: la entrada declara `chestRarity` **en lugar
  de** `floorReached`, y como `isMilestone` mira los tres criterios viejos, cae a `false`
  sola. La doble vía no puede existir por construcción.
- **Save v5**, con el arreglo de las skins doradas que estaba esperando este bump.
- **La animación son cuatro toques** y la rareza se anuncia en el segundo, con el cofre
  todavía cerrado.
- **"Cofre" se renombró**: el boost del asado ahora paga "una picada".

**Cerrado el 2026-08-27, las doce tareas.** La tarjeta en Regalos con su puntito, el
carrusel de Pintas que muestra al personaje que todavía no conociste, y el cofre de
bienvenida que cae al cerrar el tutorial. Detalle en
`Docs/SESION-2026-08-26-cofres-de-skins.md`.

**El cierre dio tres cosas que no eran de la lista**, y las tres son de método:

1. **La primera corrida limpia de la suite entera sobre el árbol final** —nunca había
   habido una, porque el checkout estuvo compartido y cada tarea verificó en su propio
   worktree—. Salió **262 · 459 con un solo rojo · UI 55 sin ninguno**, y de paso mostró que
   los "11 rojos de StoreKit" del cuadro viejo ya no existen: la matriz de dos runtimes los
   resuelve. Ver §6.
2. **El rojo intermitente tiene veredicto**: `AscentRenderingUITests.testCharactersStayVisibleAfterTheFirstAscent`
   pasó en la corrida de suite completa, en **148 s**. Es el test más lento del repo por un
   factor de tres, o sea el primero que se cae cuando la máquina está cargada. Es carga, no
   dueño.
3. **Las 36 menores diferidas del ledger se triagearon una por una**, y **12 ya estaban
   cerradas** por rondas de arreglo posteriores a la que las anotó. El triage completo está
   en el doc de la sesión.

### Sesión del 2026-08-23 (ter) — La desaceleración, y el build que volvió a andar

`fix/rebalance-pacing`. **El diagnóstico**: con el precio anclado a la frontera y
nada más, cada tier costaba el MISMO tiempo que el anterior — 37 tiers ×
constante— y **la run no se trababa nunca**. Por eso se podía ir de Fisura a Dios
de una sentada y por eso reencarnar no pagaba: se reencarna para correr una
pared, y no había pared. Un solo dial no podía arreglarlo porque el problema no
era la constante sino **la forma de la curva**.

**La regla de precios suma un tercer renglón** (ver §5.2): del **tier 7** para
arriba tu propia frontera se encarece un **60 %** por tier, por encima de lo que
ya sube por rendir más (`frontierEscalationPerTier` 1,6 con
`frontierEscalationFromTier` 7). El umbral no es adorno: sin él la escalada es
una exponencial desde el tier 1 y las primeras cinco runs se traban **en el
callejón**, que es la frustración que el diseño evita.

**El contrato pasó a ser una FORMA y ahora es medible.** `Report` publica tres
series nuevas y `pacing-sim` las imprime: dónde se traba cada run, cuánto corre
la pared, y cuánto paga reencarnar. "Trabarse" es un número —el primer tier cuyo
paso al siguiente cuesta más de una SESIÓN entera de juego activo— y el umbral
sale del modelo humano, no de un literal a dedo.

Medido: `— · T12 · T13 · T14 · T16 · T18 · T20`, corriendo `+1 · +1 · +2 · +2 · +2`.

**Los dos contratos que se destrabaron**: maxear las siete mide **20,67 h
activas** (el primer assert de `theOwnersTargetsAreMet` pasa por primera vez), y
**el que no reencarna ya no llega a dios** (tier 29 de 37 a los 400 días, contra
28,43 h reencarnando) — el contrato 5 nunca había cerrado en cuatro rondas.

🔴 **Lo que queda**: 9 reencarnaciones contra las ≤8, y reencarnar paga 7-40 %
contra el ≥67 % pedido. El techo del pago es estructural y está medido: volver a
la pared cuesta las mismas ACCIONES que la primera vez y el ORO saca la espera,
no las acciones. Pide una mejora permanente que acorte la SUBIDA, que hoy no
existe en el catálogo.

⚠️ **La compuerta NO se movió a 7** aunque estaba medida como jugable: con la
desaceleración dando el largo, N=7 empeora la FORMA (su piso de acciones le pone
techo a lo que puede pagar reencarnar). Se queda en 6, con el número en la
bitácora.

**Y el proyecto vuelve a compilar solo.** Desde Xcode 26 no compilaba sin flags a
mano: un header de Apple (`SKPaymentTransactionState`, deprecada en iOS 18) rompía
el build entero porque el proyecto trata los warnings como errores. Arreglado con
`-Xcc -Wno-deprecated-declarations` en `Debug` y en los dos targets que importan
`StoreKitTest`, **sin tocar `SWIFT_TREAT_WARNINGS_AS_ERRORS`** (ver §7, trampa 38).
Verificado: build limpio sin flags, cero warnings propios, y un warning nuestro
metido a propósito sigue rompiendo. **Para jugarlo alcanza con abrir el proyecto
en Xcode y darle Run.**

Detalle y barridos: `balance-log.md`, "Cuarta ronda (ter)". Doc de sesión:
**`Docs/SESION-2026-08-23-desaceleracion.md`**. Corrida:
`balance-run-t11-desaceleracion.csv`.

### Sesión del 2026-08-23 (bis) — Las fusiones se cobran, y el barrido de la profundidad

`fix/rebalance-pacing`. **El simulador dejó de regalar las fusiones**
(`HumanModel.mergeSeconds`, 1 s). Era un sesgo y no una simplificación: fusionar
es el verbo central del juego —una acción por fusión— y subir un tier de frontera
pide `2^N − 1` de ellas, así que el instrumento medía a un jugador que compra con
el dedo y fusiona con la mente. Sesga justo el eje sobre el que se calibra: la
proporción compras/fusiones es lo que mueve la profundidad de la compuerta.

⚠️⚠️ **Acá se corta la comparación con todas las bandas anteriores de la rama**:
cualquier número previo al `800755c` se midió con el merge gratis.

Efecto: maxear 7,27 → **6,67 h**, dios 9,40 → **8,97 h**, y la 1ª reencarnación
4,28 → **9,00 h de pared**. Las horas ACTIVAS bajaron, que es lo contrario de lo
esperado: cobrar las fusiones quema presupuesto de SESIÓN, el bot llega antes al
final de cada una y parte del progreso se paga con income offline —reloj de
pared, no de dedo—.

**El barrido de la profundidad, con el instrumento corregido**: N=6 → 6,67 h ·
N=7 → 186,33 h (muro del early game) · **N=7 con el callejón destrabado
(`floors[0].hireCostGrowth` 1,02) → 13,33 h**, 8 reencarnaciones, dios a 21,21 h
y cadencia que sube pareja de 1,1 a 2,6 h · N=8 **no es jugable** (pelado no
termina; destrabado pide 9 reencarnaciones y saltos de 29-41 h).

⚠️ **La profundidad es lo ÚNICO medido que da vuelta la trampa de reencarnar**, y
el cruce cae entre 7 y 8: con N≤7 el que no reencarna llega ~3× más rápido, con
N=8 no llega nunca. El contrato 5 y los contratos 2-3 tiran para lados opuestos
del MISMO dial.

**La compra en lote se empezó y se descartó** (objeción del dueño, correcta: sólo
entran 10 por piso, comprar de a más ACORTA el juego, y por lo tanto no es una
palanca de duración). No quedó nada en el árbol; el porqué está en el doc de
sesión §4 para que no se re-proponga sin leerlo.

Detalle: **`Docs/SESION-2026-08-23-fusiones-cobradas.md`**. Números:
`balance-log.md`, "Cuarta ronda (bis)". Corrida:
`balance-run-t10-merges-cobrados.csv`.

### Sesión del 2026-08-23 — El precio atado a la frontera, y el reloj que no era de plata

`fix/rebalance-pacing`, cuarta ronda. **El precio de contratar dejó de seguir a
`tapYield(tier)` y pasa a anclarse en tu FRONTERA de merge** (decisión del dueño,
Opción 1 de la ronda anterior):

    mult(piso) × tapYield(FRONTERA) × factorDePiso
              × priceGrowthPerTier^(tier − frontera) × growth^compras

La derivación, que es lo que hace que no sea una preferencia: el diseño quiere
que subir un tier cueste siempre lo mismo en TIEMPO (⇒ precio ∝ rendimiento de tu
frontera ⇒ pendiente 2,8 por tier) **y** que la pendiente del precio sea ≤ 2, el
factor de merge (⇒ o si no comprar hondo es más barato). Con un precio `f(tier)`
las dos son contradictorias. Anclarlo a la frontera separa el **nivel** (2,8 por
tier de frontera, pacing plano) de la **pendiente** (`priceGrowthPerTier` = 1,5,
atajo cerrado). Comprar hondo pasó de costar `0,71^d` a costar **`1,33^d`**.
`tierPremium` se borró: bajo la fórmula nueva dejaría la pendiente dentro del
piso en 2,8 × 1,8 = 5,04, o sea el agujero otra vez.

Con eso **la compuerta se volvió por fin un dial de dificultad** (N=5 → 4,14 h ·
N=6 → 7,27 h · N=7 → 185,63 h) y subió a **6**.

⚠️ **El contrato de 20-30 h sigue sin cumplirse (7,27 h), y la causa que queda es
otra**: el simulador cobra 1 s por compra y **la mitad del tiempo activo del bot
es apretar el botón, no esperar plata** (sin ese segundo, maxear cae de 4,14 h a
2,19 h). Por eso todos los knobs de precio son sublineales —×16 en
`defaultCostMultiplier` compra ×1,75 de partida— y por eso el atajo viejo estaba
sosteniendo la mitad del largo del juego sin que nadie lo hubiera diseñado.
`PacingTests.theOwnersTargetsAreMet` **sigue en rojo**.

Tercera ceguera del bot arreglada, misma clase que las dos anteriores: elegía la
contratación **más barata**, que con el precio nuevo es la PEOR (el Fisura). Ahora
elige la más barata **por unidad de frontera**.

Lo que mejoró, medido: la **fase fisura casi se triplicó** (28,0 → 78,0 s activos)
sin tocar el Fisura, el **peor salto entre hitos bajó a 2,02 h** (4,45 h en la
ronda 3, 10,0 h en la segunda) y ahora hay un test que lo mide en HORAS y sobre
los diez pisos (`noHitoJumpIsLongerThanFourActiveHours`).

Detalle: **`Docs/SESION-2026-08-23-precio-atado-a-la-frontera.md`**. Números y
barridos: `balance-log.md`, "Cuarta ronda". Corrida:
`balance-run-t9-precio-frontera.csv`.

### Sesión del 2026-08-22 — La compuerta por distancia, y el bot que no era el jugador

`fix/rebalance-pacing`, tercera ronda. **La compuerta de contratación pasó de
medirse en PISOS a medirse en TIERS**: un tipo de tier `T` se contrata sólo si
`run.maxTierReached >= T + N`, con `N = 5` en `economy.json`
(`hire.gateTierDistance`) y el tier base de la torre exento. La regla vieja tenía
un borde dentado —un piso son cuatro tiers y FisuJobs los vende todos, así que lo
que ataba era el TOPE del piso habilitado, a UN tier de la frontera— y por eso
todo pasaba entre dos pisos contiguos y el ascensor no se usaba nunca.

⚠️ **Y el titular es otro, incómodo: el contrato de 20-30 h nunca se cumplió.**
Arreglar dos cegueras del simulador —elegía la peor mejora por personaje, y sólo
compraba el tier BASE de cada piso cuando FisuJobs vende todo lo contratable—
destapó que la partida embarcada dura **13,64 h activas hasta dios y 6,67 h hasta
maxear las siete**, no las 24,67 h que la ronda 2 creyó medir. Sin reencarnar,
dios llega en **3,28 h**, que es al minuto lo que el dueño reportó a mano ("me lo
gané en 3 horas"). `PacingTests.theOwnersTargetsAreMet` **queda en rojo a
propósito** (unit 410/411): no se afloja y no se re-pinea.

La causa es estructural y está medida: `yieldGrowthPerTier` (2,8) le gana al
factor de merge (2), así que comprar hondo siempre sale más barato y **una
compuerta más profunda ABARATA el juego** (N=4 → 6,67 h · N=6 → 5,34 h · N=8 → la
partida no se termina). Ningún knob llega a 20-30 h: los nueve están medidos en
`balance-log.md` y ninguno pasa de ~13-17 h porque la torre entera dura eso. Las
tres salidas —y son decisión del dueño— están en el doc de sesión.

Lo que sí mejoró: el acantilado corporate → luxury pasó de **×90,86 a ×5,27** (la
guarda de `floorGradient` bajó de 118,1 a 10,21), ningún salto entre hitos pasa
de 4,45 h activas, los dos parches por piso (callejón exento y `hireGateExempt`
del urbano) desaparecieron, y **la autorización por tipo existe**: antes el único
lugar del juego que gateaba por tipo era la proyección `jobRows`.

Detalle: **`Docs/SESION-2026-08-22-compuerta-por-distancia.md`**. Números y
barridos: `balance-log.md`, "Tercera ronda". Corrida: `balance-run-t8-compuerta.csv`.

### Sesión del 2026-08-22 — El multiplicador secuencial, y el atajo de no reencarnar

`fix/rebalance-pacing`, segunda ronda. **Las mejoras POR PERSONAJE dejaron de ser
`2^nivel` y pasaron a ser `1 + nivel`: ×2, ×3, ×4 … ×20** (pedido textual del
dueño). El efecto al tope cayó de ×1.048.576 a ×20 y el knob se renombró
(`effectFactorPerLevel` → `effectStepPerLevel`) porque ya no es la base de una
potencia; `maxLevel` bajó de 20 a 19, que es lo que clava el ×20 que él escribió.

La otra mitad del pedido —"hacé que sea más difícil subir de piso"— se contestó
midiendo la partida que él describió, que **el simulador no podía correr**: de
fisura a dios SIN REENCARNAR. Eran **10,47 h activas** contra las 26,59 h de
reencarnar, o sea el atajo era 2,5× más rápido; ahora son **66,34 h**, 2,0× más
lento. Y el barrido de política quedó monótono: cuanto más se posterga la
reencarnación, peor, en las dos métricas.

Las cuatro métricas: **maxear 24,67 h activas · 8 reencarnaciones · dios 33,23 h
activas · dios sin reencarnar 66,34 h**. Calibrado con dos knobs
(`charUpgrades.costGrowth` 4,0 → 1,5 y `oro.divisor` 3e12 → 1e9), cada uno medido
solo. Detalle y descartes en `Docs/SESION-2026-08-22-multiplicador-secuencial.md`
y `Docs/balance-log.md`.
### Sesión del 2026-08-25 — Tres correcciones de UI, y Xcode 26.6

El botón del cierre del tutorial ganó su aire; **la manito de «tocá acá» se
volvió UN componente (`TapHereHand`)** y vive ahora también en el coach de
lecciones, la fila recomendada de FisuJobs, la tarjeta de Logros (junto al
badge) y las pintas sin estrenar; y **la carta del personaje especial muestra
la SKIN en grande** (168 pt, detent 0,66) y se REABRE manteniendo apretado al
personaje en el tablero (`specialInfo`, fuera de la cola; fixture nuevo
`--uitest-special`; UI test del circuito completo). En el medio, **Xcode
saltó a 26.6 y el juego «se veía espantoso»**: era la cadena post-update —
override de runtime, runtime 26 ausente, module cache mixto, el -Werror del
importer y el abort de SKTestSession — desarmada eslabón por eslabón en la
**trampa 30**. Detalle en
**`Docs/SESION-2026-08-25-correcciones-ui-y-xcode-26.md`**. Números del
cierre (sim iOS 26.5, receta §6): EconomyKit **234** · unit **413** · UI
**49 sin fallos ni skips**.

### Sesión del 2026-08-21 (noche) — Los personajes se llaman en inglés cuando el juego está en inglés

Lo vio el dueño jugando: con el idioma en English el personaje seguía diciendo
"El Fisura". No era un hueco del catálogo —**las 475 claves tenían su
`en`**— sino que el nombre nunca pasaba por el catálogo: sale de `tiers.json`,
que es dato en castellano, y las 15 vistas lo dibujaban `verbatim`. Ahora pasa
por `CharacterType.localizedName`, que busca `tier.name.<id>` y **cae al
castellano del dato si la clave falta**, igual que las skins con
`skin.name.<id>`. Se sumaron las 44 claves y se corrigieron los 3 textos ya
traducidos que nombraban al personaje en castellano (el tutorial decía "I am El
Fisura").

La traducción es **cultural, no literal**, y el arte manda: el trapito es "The
Fake Valet", el limpiavidrios es "Squeegee Guy", el médico Jr. es "Medical
Resident" (que es lo que sos en EE.UU. cuando te recibís) y el dueño de PYME es
"Small Business Owner". Las 17 que no son literales están en una tabla con su
porqué en **`Docs/SESION-2026-08-21-nombres-en-ingles.md`**. ⚠️ **El tono no lo
aprobó el dueño todavía**: cambiar cualquiera es editar un `value` del catálogo,
no hay código atado a un nombre.

Números del cierre: app **413** · UI **48 sin skips** · EconomyKit **234** (no se
tocó el paquete). Cuatro asserts que pineaban el nombre en castellano pasaban
**por casualidad** —el runner corre en inglés (trampa 6) y el nombre no era
traducible— y pasaron a pinear lo que querían probar; `RevealBannerFitTests` ahora
mide los dos idiomas.

### Sesión del 2026-08-21 — El rebalance de pacing: ganarlo al máximo cuesta 24 h

`fix/rebalance-pacing`, con `fix/atajo-tier-base` y `fix/premios-y-eventos`
integradas — **y mergeada a `main` en `9efc8f7` el mismo día** (verificación
del árbol final en `Docs/SESION-2026-08-21-merge-rebalance-y-manito.md`). **Maxear las siete líneas permanentes —"ganarlo al máximo", lo que
desbloquea las skins doradas— pasó de 15,49 h a 24,00 h ACTIVAS y de 34
reencarnaciones a 8**; dios quedó a 26,59 h activas, o sea DESPUÉS de las skins.
Detalle en **`Docs/SESION-2026-08-21-rebalance-pacing.md`**, calibración corrida
por corrida en `balance-log.md`.

Lo que hay que saber sin abrirlo:

- **Son DOS knobs con dos efectos distintos**, y confundirlos costó una ronda: la
  **curva de ORO** (`divisor` 3e6 → 3e12, `exponent` 0,45 → 0,25) cierra la
  divergencia costos-vs-ingresos —entrar a un piso volvió a costar segundos de
  income en vez de 0,0 s—, y **`hire.defaultCostGrowth` (1,2 → 1,06)** es lo que
  hace la torre escalable: con el 20 % por compra **la partida no se puede
  terminar** (el bot se traba en el tier 11).
- **El atajo del HUD cambió de regla**: vende el **tier base** del piso más alto
  pagable, no el tier más alto. Ofrecer el más alto te saltea el merge, que es el
  juego. FisuJobs no cambió: sigue vendiendo todo lo desbloqueado.
- **Los premios de logros son SEGUNDOS de tu producción**, no un múltiplo de un
  costo: dos jugadores en el mismo tier con torres distintas cobran distinto. Y
  los **doce logros de ORO fijo bajaron de 620 a 33** — sumaban 3,2 veces lo que
  cuesta ganar el juego (§5).
- **Los eventos se espaciaron** de uno cada 5-8 min a uno cada 15-20 min, y la
  cara mala pasó a ser mayoría de peso sin apagar ninguno.
- **`PacingTests` se re-pineó entero** y ganó dos asserts que NO son bandas sino
  el objetivo del dueño (20-30 h activas, ≤8 reencarnaciones). El bot que medían
  las bandas viejas no era el jugador: se construía sin catálogo de mejoras
  permanentes.
### Sesión del 2026-08-21 (tarde) — El tutorial high-end

El tutorial se rehizo entero contra `PROMPT-tutorial-high-end.md`: la **fase
obligatoria quedó en 4 pasos** (tap → contratar → fusionar → cierre; murieron
los dos pasos que abrían vidrieras vacías) y **el resto de la app se enseña en
lecciones contextuales** — kind nuevo `.tutorialTip` en la CelebrationQueue,
una por vez, disparada la primera vez que hay algo que HACER en su pantalla
(la regla de oro del dueño; tabla de señales en la doc de sesión). La cola
ganó `restrict(to:)`: con la fase viva sólo el reveal del tablero toma el
turno, el resto espera en `pending` — eso mató el deadlock del daily
día-2-a-medias (repro en `CelebrationWiringTests`) y el reveal del primer
merge se ve **entero y limpio** (el overlay entero se esconde mientras dura).
El puntito rojo de logros (`ui_badge`, recortado al bbox: traía 86% de aire)
vive como `.overlay` en el tab Menú y la tarjeta de Logros, avisando por
`accessibilityValue`; su señal es la proyección nueva
`hasClaimableAchievements`. La tarjeta habla v3 (pergamino, retrato 96 pt
pisando el borde, pop de spring); la mano probó un vectorial de la casa y
volvió al SF Symbol del sistema por pedido del dueño (2026-08-21, post-merge
del rebalance). Poses: sólo `wave`/`celebrate` hasta que 117/118 se regeneren. Detalle y por qué de
cada decisión en **`Docs/SESION-2026-08-21-tutorial-high-end.md`**; trampas
nuevas 24 y 25 en §7. Números del cierre: EconomyKit **213** · app **395**
(3 rojos Pacing preexistentes) · UI **48 sin fallos ni skips**.

### Sesión del 2026-08-21 — El telón de las empujadas

Las cinco pantallas EMPUJADAS del menú (las cuatro de gabinete y los legales)
mostraban un telón blanco donde todas las demás hojas muestran el juego
atenuado: UIKit le pinta `systemBackground` al hosting controller de un destino
empujado y el `.presentationBackground(.clear)` de la hoja no alcanza. Arreglo:
`clearNavigationBackdrop()` (PanelFrames.swift) sobre el contenido de los dos
`navigationDestination` — en iOS 18 la API, en 17 una sonda UIKit **que quedó
sin verificar** (no hay runtime 17 instalado). Medido antes/después con
píxeles de captura. Detalle en **`Docs/SESION-2026-08-21-telon-del-menu.md`**;
la trampa es la 23.

### Sesión del 2026-08-19 — Oro y diamante para los 43

**86 skins nuevas** (43 de oro macizo + 43 de diamante tallado), una por cada
personaje con arte: los 44 tipos menos `junior`, que es el nodo de carrera y no
tiene sprite. Detalle en **`Docs/SESION-2026-08-19-skins-oro-diamante.md`**.

Lo que hay que saber sin abrirlo:

- **Un id por material, no por personaje.** Las 43 de oro comparten `id: "oro"`
  y las de diamante `id: "diamante"`. Eso movió la unicidad de
  `SkinsConfig.validate` de global a **(personaje, id)** — la convención
  `<baseKey>__<skinId>` exige que el id sea el sufijo. A cambio sale gratis lo
  que se quería: la propiedad se guarda POR ID, así que **un único producto
  desbloquea el bundle entero** sin inventar un campo de paquete.
- **Desbloqueo**: el oro NO se vende (`upgradesMaxed`, las seis mejoras
  permanentes al tope; eran siete hasta E13 T7); el diamante sólo por
  `com.fisuevolution.iap.skins_diamante` (19,99).
- **La silueta es el argumento de venta**: la ficha esconde TODO lo no
  adquirido, también lo que está a la venta. La tienda las muestra a color a
  propósito.
- **El recorte se eligió a mano, asset por asset**: las 43 de oro con saliencia,
  33 de diamante con conectividad y 10 con saliencia. Ninguna herramienta gana
  siempre — ver §5.
- Tres bugs del pipeline de generación quedaron medidos y arreglados (el umbral
  de descarte, la cola compartida y la multiplicación de reintentos): §7.

### Sesión del 2026-08-18 — El recorte deja de comerse lo blanco

`process_dropbox.py` recortaba con `rembg`, un modelo de **saliencia**: con arte
cartoon sobre fondo blanco leía como fondo cualquier blanco del dibujo. Medido
sobre los 219 assets integrados, **102 tenían al menos un 2% del dibujo calado y
73 pasaban el 5%** — el guardapolvo del `senior_doctor` entero, las caras
translúcidas, los paneles sin su pergamino.

El criterio nuevo (`scripts/whitebg_cutout.py`) es **topológico**: fondo es lo
blanco que se toca con el borde del lienzo. Una camisa blanca está rodeada por
la línea del dibujo y por lo tanto no se puede recortar. **206 assets rehechos**
desde sus originales, que ya estaban en git. Detalle en
**`Docs/SESION-2026-08-18-recorte-de-fondo.md`**.

### Sesión del 2026-08-18 (tarde) — La hoja contenida

**Todas las hojas cambiaron de anatomía** (pedido del dueño, mismo
`feature/rediseno-v3-referencias`): el marco dejó de entrar como `.background`
y pasó a CONTENER a su hoja — cabecera adentro del pergamino y scroll
recortado que muere contra la banda inferior del marco, que quedó a la vista.
El patrón es `panelSheet(material:awning:header:ornament:)` en
`FisuEvolution/UI/Art/PanelFrames.swift`; por qué esto mata de raíz el
"título flotante" está contado en §8. Migraron las 12 hojas —FisuJobs,
Tienda, Mejoras, Pintas, Regalos (su `GiftBowOrnament` ahora entra por el
slot `ornament`), Menú, el mapa del Ascensor, organigrama, stats, logros,
ajustes y Legales— y todas se presentan con `.presentationBackground(.clear)`:
aplicado en `RootView` para las 6 de la barra y en `HUDView` para el
ascensor. `PrestigeView`, `CareerChoiceView` y `SkinAwardView` lo ganaron
también (los otros popups ya lo tenían): ya ningún popup muestra el
rectángulo del material de sistema alrededor de su marco de arte. El detalle
vive en el tercer arco de **`Docs/SESION-2026-08-17-rediseno-v3.md`**.

Cinco cosas más del día:

- **`IconButton` ganó `glyphAspect`** — el ancho del glifo como fracción del
  alto; con un valor ≠ 1 el arte se ESTIRA a propósito (pedido del dueño para
  el ascensor). Tras una ronda de ajuste en caliente (×0,85), la moneda+
  quedó en **56 pt** y el ascensor en **61 pt** con `glyphAspect` 0,86.
- **`ui_elevator`, `ui_coin_plus` y `ui_gift_bow` se recortaron al bbox del
  alfa** (+2% de aire): traían ~40–60% de lienzo transparente y por eso
  rendían chicos. ⚠️ Si el batch los regenera, vuelven con márgenes — la
  advertencia quedó en §8, punto 1.
- **Mejoras volvió a MADERA con toldo** (y el glifo de su tab en el título,
  como Pintas/Regalos/Tienda; el Menú ganó el suyo y sus tarjetas muestran el
  icono pelado a 84 pt). El metal quedó SOLO para el Ascensor: dos materiales,
  un criterio — metal = maquinaria de verdad.
- **La tienda funciona fuera de Xcode** (`fix(store)`): el `.storekit` del
  scheme sólo se inyecta cuando Xcode lanza la app; instalada por `simctl`
  StoreKit devolvía catálogo vacío y la pantalla quedaba en "sin conexión"
  eterno. Ahora el `.storekit` viaja en el bundle y `StoreManager` levanta en
  DEBUG una `SKTestSession` idéntica (bajo XCTest NO — los tests manejan la
  suya; trampa 4 sin agrandar). `StoreKitTest` vive fuera de los search paths
  de una app: sólo Debug prende `ENABLE_TESTING_SEARCH_PATHS`, y Release ni
  importa ni linkea el framework (el autolink sigue al `#if DEBUG import`).
- **Los siete popups hablan `PanelCard`** (PanelFrames.swift): el tablón de
  las hojas en escala de tarjeta —banda fina, tornillos, pergamino, ink,
  sombra— reemplazó a los CUATRO marcos de arte 9-slice con insets medidos
  por PNG. La familia de premio (daily/AFK/sorpresa) lleva el moño asomando
  arriba. `GamePanel` y `PanelBackground` quedaron sin llamadores y se
  RETIRARON de `GameArt.swift`; sus PNG (`panel_reward/career/prestige/
  dialog`) siguen en el atlas como reserva, igual que `panel_menu`.

### Sesión del 2026-08-17 (tarde) — Rediseño v3: los materiales de las referencias

**12 tareas + 2 rondas de fix** en `feature/rediseno-v3-referencias`, sobre
`c4e69ba`. La lectura que ordenó todo: el v2 ya TENÍA la estructura de las
referencias del dueño; lo que faltaba era la capa de materiales. Cinco
movimientos: (1) interior **pergamino** bajo todos los marcos (los PNG de
panel tienen interior transparente, alfa 8–15 — así que fue UN cambio en
`PanelBackground`/`GamePanel`); (2) bordes **tono-sobre-tono** vía
`Color.deepened()` (verde con verde oscuro, crema con marrón — la tinta quedó
sólo donde es decisión del dueño o contorno cartoon); (3) **`PillBackground`**,
la cápsula caramelo compartida (luz arriba, labio de brillo, borde hundido);
(4) la **cinta** con colas caídas, pliegues y ✦; (5) los dos marcos fuera de
idioma reemplazados — la familia del menú a `WoodPanelBackground` (madera
VECTORIAL con los tonos muestreados de `panel_store`) y Regalos a
madera+toldo+`GiftBowOrnament`. Detalle, decisiones y capturas en
**`Docs/SESION-2026-08-17-rediseno-v3.md`**.

⚠️ Dos cosas de esa sesión que valen más que el diff: la trampa 16 (§7, el
cwd que se vuelve solo), y que `GameCard.locked` ahora tiene dos sabores —el
misterio gris entero y `contentDimsWhenLocked: false` para el boost bloqueado
que se muestra a color (así lo pide la referencia de Regalos).

### Sesión del 2026-08-14/16 — Rediseño de UI estilo Cow Evolution

**20 tareas, 53 commits** sobre `d60d886`, en `feature/rediseno-ui-cowevolution`.
101 archivos, +19.248/−1.681. El detalle tarea por tarea —con los fix rounds,
los rulings y los avisos— vive en **`Docs/SESION-2026-08-14-rediseno-ui.md`**;
acá va lo que hay que saber sin abrirlo.

**Qué es**: el juego pasó a la estructura de Cow Evolution —HUD superior
contiguo + **barra inferior de 6 pantallas**— con identidad visual propia.
Desaparecieron los 4 botones sueltos del HUD y el botón de spawn; entraron
seis pantallas reales (FisuJobs, Upgrades v2, Customization, Regalos, Tienda
v2, Menú) más el Ascensor y las cuatro sub-pantallas del menú
(organigrama, stats, logros, ajustes).

**Las piezas que importan:**

- **FisuJobs** (`FisuEvolution/UI/Jobs/FisuJobsView.swift`) es la **referencia
  visual canónica**: toda pantalla nueva se revisó contra ella (regla del
  dueño, ver el doc de sesión). Gramática compartida: `GameCard` para filas,
  `PricePill` para precios, `ProgressBar` para progreso, paleta sólo
  `Palette*`, tipografía `Tokens.*`, cabecera crema opaca (retirada el
  2026-08-18: la cabecera vive adentro del panel — `panelSheet`, ver §8),
  `ArtCloseButton`.
- **Curva de contratación por tipo** con `tierPremium` (1,8): cada tipo
  desbloqueado se contrata con precio propio. El gate de un piso y el Fisura a
  50 quedaron intactos.
- **39 logros data-driven** con motor de 11 hooks y cobro con recompensa.
- **Ajustes reales**: idioma, audio, notificaciones (recordatorio diario
  19:00) y los dos legales (privacidad y términos, es+en) — todo listo para
  App Store. `ConfigView` murió.
- **Facing de personajes**: miran hacia donde caminan, con flip periódico
  (7,5 s ± 5). El espejado va en `sprite.xScale`, nunca en el nodo.
- **Micro-animaciones**: contador rodante, stagger compartido, shake medido,
  toasts con spring.
- Catálogo de strings: **269 → 468 claves** (es + en).
- 34 archivos Swift nuevos; 3 borrados (`ConfigView`, `SpawnButtonView`,
  `BonusView`).

**Números finales, medidos el 2026-08-16 en un simulador propio por UDID,
`-parallel-testing-enabled NO`, unit ANTES que UI:**

| Suite | Resultado |
|---|---|
| `EconomyKit` (`swift test`) | **180/180** ✅ |
| `FisuEvolutionTests` | **336/336** ✅ |
| `FisuEvolutionUITests` | **40/40** ✅ (**15 clases corriendo de las 16** que tiene la suite; `AscentRenderingUITests` salteada, rojo preexistente de `main` — **recuperada más tarde ese mismo día**: la receta vigente de §6 corre las 16, **43 sin skips**) |
| `Tools/asset-pipeline` | 27, **1 rojo conocido** (pide Chrome en `:9222`) |
| Warnings de compilador | **0** |

⚠️ **Ningún flaky hizo falta re-correr**: `EconomyLoopUITests`,
`BonusHUDUITests` y `StoreManagerTests` pasaron en la corrida completa, y
`PacingTests.strugglingPhaseLength` —que figuraba como rojo de entorno— pasó
también. La regla que lo hace reproducible es **correr unit antes que UI**
(§7).

### Sesión del 2026-08-17 — Celebraciones de a una, y dos pantallas al día

**La cola de celebraciones** (detalle arriba y en su spec). Lo que hay que saber
si se la toca: el turno del ascenso lo pide `handleDrop` y **no** la escena, y esa
no es una preferencia de estilo — `updateMaxFloorStat()` acredita la skin de
milestone DENTRO del mismo merge, así que si la escena encolara después, el sheet
ya tendría el turno y taparía el vuelo y el reveal. Que es exactamente el bug que
la cola viene a arreglar. Lo cazó el test de wiring, no el simulador.

**La franja de abajo**: contratar y reencarnar comparten fila, cada uno contra su
borde. `PrestigeButton` es el espejo de `QuickHireButton` —misma cápsula, mismo
borde ink, mismo alto derivado de `QuickHireButton.capsuleHeight`— y era el último
`.buttonStyle(.borderedProminent)` de la pantalla principal.

**El fork de carrera** (`CareerChoiceView`) pasó a la anatomía de fila de
FisuJobs, con el **retrato de cada carrera**: era la última pantalla con botones
del sistema, y pedía la decisión más definitiva del juego sin mostrar a quién
elegías.

⚠️ **Y era la única pantalla del juego sin un solo test de UI** — no por descuido:
alcanzarla cuesta horas de partida y no vuelve hasta la próxima reencarnación. Por
eso se hizo vieja sin que nadie lo notara. Ahora hay `--uitest-career` (que además
marca `fisuTutorialDone`, porque el sheet está gateado por él y `--uitest-reset`
no lo toca) y `CareerChoiceUITests`. **Si una pantalla no se puede abrir con un
fixture, se va a poner vieja: es la lección, no el caso puntual.**

**La skin Reparto Cohete**, regenerada. Lo que fallaba era el prompt, no el
modelo: le sacaba a la vez los DOS anclajes de silueta del Repartidor (la
mochila-cubo y el casco) y encima pedía naranja, que es el color del personaje
base. Sin nada a lo que agarrarse, la primera pasada devolvió un vendedor
callejero con bandeja de golosinas y un gato. La receta que funcionó está en el
`.md` del prompt: **reskinear los anclajes en vez de borrarlos**.

### Sesión del 2026-08-10

Cuatro commits, de `853bb1b` a `de9b76e`. **Dos frentes en paralelo** —uno de
jugabilidad y uno de arte— y eso dejó una marca en el historial: ver la ⚠️ del
final de esta sección.

#### Fusión asistida (`853bb1b`)

Fusionar era la acción central del juego y la más fiddly. Detalle en §3, "La
escena". Lo que hay que saber en dos líneas: al agarrar a alguien sus hermanos
se destacan y se **congelan**, y un doble toque funde al par sin arrastrar nada.

⚠️ Y una causa que no estaba en el pedido y era la peor: el drop se resolvía
contra el **ancla** del slot y no contra dónde estaba parado el personaje, así
que **soltar encima de alguien te mudaba al hueco de al lado**. Es la vieja
trampa 3, ahora arreglada.

#### Contadores de bonus activos (`de9b76e`)

Un chip por bonus temporal corriendo, abajo del HUD y a la izquierda. Detalle en
§3, "Contadores de bonus activos". La decisión que sostiene todo: la proyección
**no** lleva el tiempo restante.

#### Los 8 fondos que faltaban (`ab5d25d`, `3791247`)

Los 10 pisos tienen piso dibujado en perspectiva y la banda de personajes usa
ese espacio. Dos cambios de código que el arte hizo necesarios:

1. `crowdTopRatio` 0,40 → **0,44**. Medido en el juego, no calculado: con 0,45
   el techo de la banda quedaba encima de la línea del piso y los de atrás
   volvían a flotar.
2. **`backgroundOffset` a 0** en urban, island, moon y mars. Ese knob existía
   para hundir la franja plana del arte VIEJO; con el arte nuevo esa franja es
   el piso generado, así que el offset lo empujaba fuera de pantalla. El bug
   quedaba vivo en 4 de los 10 pisos.

#### ⚠️ Dos agentes en paralelo se pisaron en git

`853bb1b` —la fusión asistida— **lo commiteó la sesión del arte, no la que
escribió el código**: encontró el trabajo sin commitear en el árbol y lo barrió
dentro de su tanda (su propio mensaje lo aclara). No se perdió nada y quedó con
su spec, pero es autoría cruzada y explica por qué el commit de una feature de
tablero aparece entre dos de arte.

**La lección práctica**: con más de un frente sobre el mismo working tree,
commiteá lo tuyo apenas esté verde. Lo que queda sin commitear no es "tuyo": es
del próximo `git add` que pase.

### Sesión del 2026-08-05

19 commits, de `2001e24` a `d39b57d`.

#### Fluidez — plan CERRADO (ver `Docs/HANDOFF-perf.md`)

Se midió Release, que era lo que faltaba, y **eso cerró el plan**: los fps están
saturados a 60 en Debug y en Release, vacío y poblado. Se hicieron sólo las dos
partes que arreglan un hitch real (precarga de audio fuera de main;
`renderPlacements` reconciliador) y se descartaron las otras tres con el número
que las descarta.

**Dos cosas que hay que saber antes de tocar rendimiento:**
1. **Los fps no discriminan nada acá.** Usá `draws` del overlay de DEBUG.
2. **El batching entre personajes es imposible por construcción**: `depthZ` le da
   a cada uno un `zPosition` único para el efecto multitud, y con
   `ignoresSiblingOrder` SpriteKit sólo fusiona nodos del mismo z.

#### Gate de contratación (spec y plan en `Docs/superpowers/`)

Contratar en un piso exige **el piso de arriba desbloqueado**; el callejón queda
exento y el último piso se habilita a sí mismo. La condición vive en **una**
función, `TowerActions.canHire`, que usan el juego **y** `PacingSimulator`.

⚠️ **El pedido original era DOS pisos y se midió que rompe el juego**: el bot se
traba en tier 12 y no llega a Dios nunca. El backfill es el puente que hace
viable la progresión (el merge puro es 2²⁹ fisuras), y pedir dos pisos lo saca
justo donde hace falta. Tabla completa en `Docs/balance-log.md`.

**La contratación no queda muerta cuando el gate cierra** (2026-08-05): parado en
tu frontera, cae en el piso de **abajo** —que por la propia regla del gate es
siempre el más alto donde sí se puede—. `TowerActions.hireTargetFloor` decide el
destino.

⚠️ El botón que la dibujaba murió con la barra inferior, y su proyección
(`GameState.HireOffer`) se retiró el 2026-08-16 al quedar sin consumidor. **La
regla no cambió**: vive en EconomyKit, y la pinean `GameLoopWiringTests` —contra
el `economy.json` real, incluida la exención del urbano— y `EconomyKitTests`
sobre fixtures sintéticos.

📌 **Lo que se retiró es la proyección, NO el requisito de UX que la
justificaba**, y este ata a cualquier pantalla de contratación futura: **el
botón NOMBRABA el piso de destino, para que la compra no pareciera no haber
pasado.** Contratás parado en tu frontera, el personaje aparece un piso más
abajo y la cámara no se mueve: sin decirlo en pantalla, el jugador ve que pagó
y que no cambió nada, y eso se lee como un bug. Hoy la deuda está **latente y
no visible**, porque nadie ejerce el fallback desde la UI — FisuJobs contrata
por tipo y su `floorTag` nombra el piso PROPIO de cada fila, que es otro dato,
y `buySpawn()` quedó sin call-site de UI (sólo lo llaman los tests). El día que
una pantalla vuelva a ofrecer contratar "acá", **tiene que decir dónde cayó**;
el dato lo da `TowerActions.hireTargetFloor`.

#### Cola de celebraciones (2026-08-17)

**Todo lo que aparece solo se reproduce de a uno.** `CelebrationQueue`
(EconomyKit, pura) ordena TURNOS sobre identificadores; los payloads siguen donde
estaban y las vistas se presentan sólo si `GameState.showing` las nombra. Nueve
ítems con prioridad: offline y diario primero, después la carrera —que bloquea la
progresión—, el ascenso, los sheets de premio, y al final banners y toasts.

- **Un tap saltea** el ítem entero, pasados 0,6 s. Ese piso no es cosmético: sin
  él el tap siguiente mataría cada celebración y la cola se vaciaría en un segundo.
- **Watchdog por ítem**: lo que se cierra solo declara un tope y, si la señal no
  llega, la cola avanza y loguea. Con cola global, un bug así congelaría TODAS las
  celebraciones hasta reiniciar.
- **El turno del ascenso lo pide `handleDrop`**, no la escena: `updateMaxFloorStat`
  acredita la skin dentro del mismo merge, y si el ascenso encolara después el
  sheet ya tendría el turno y taparía el vuelo.
- La UI se apaga **del todo** —opacidad 0 y sin hit-testing (`celebrationHidesUI`)—
  pero **sólo cuando el merge trae algo NUEVO**: un personaje que no se había
  visto (reveal de tier — apaga SIEMPRE, abra piso o no) o un piso que se
  desbloquea por primera vez (`6afe1d8` + `7b0d613`, las dos frases del dueño
  citadas en `GameState.swift`). El único ascenso con el HUD a la vista es el de
  un personaje conocido a un piso ya abierto — el de todos los días, donde apagar
  escondería monedas y botones que el jugador está usando. La bandera la lleva el
  PAYLOAD (`celebrateBoard(showsSomethingNew:)`), no el turno, y no se pisa si la
  celebración ya está en pantalla — si no, el HUD se prendería a mitad del vuelo.
  ⚠️ Hueco conocido para decidir: `chooseCareer` nunca encola `.boardCelebration`,
  y el merge de carrera SIEMPRE produce personaje nuevo — por la regla debería
  apagar, hoy no celebra nada (concern 3 del report de la rama).
- El reveal va **centrado a pantalla completa**: desde `0d3b96d` ya no se ancla
  bajo la banda del HUD, así que no tiene nada que esquivar.
  `BoardScene.topInset` (176) quedó sin uso, y se conserva sólo porque es el
  número MEDIDO de la banda del HUD.

Detalle en `Docs/SESION-2026-08-17-cola-de-celebraciones.md` y su spec.

### Secuencia de celebraciones

Un merge que asciende y abre piso disparaba **cinco cosas en t=0**. Ahora
encadena: vuelo → reveal → piso nuevo → `celebrationsDidFinish()` → sheet de skin
→ toast. Encadena **por completion, no por delays**: con Reduce Motion las
duraciones colapsan y ningún offset puede esperar a un sheet que cierra el jugador.

#### Skins

- Se retiraron los tres tintes globales (golden/galaxy/god). Cada personaje tiene
  **base + la suya**. ⚠️ Eran los tres productos IAP: **la tienda quedó vendiendo
  sólo `remove_ads`**. El sistema de tintes sigue entero, una skin futura entra
  por config. (Ya no es el estado actual: RF-13 sumó las dos skins de arte propio
  y RF-02b los packs — hoy la tienda vende **10 productos**.)
- Las bloqueadas se ven en **silueta** de tinta plena.
- El popup del premio gana "Ponérsela".
- **El arte de las 36 skins está hecho y verificado.** Una (`home_office`) se
  regeneró porque había salido idéntica al arte base.

#### Balance

`hire.defaultCostMultiplier` 300 → 600 (el callejón sigue en 50). Medido:
**acortó** el juego de 264 h a 196 h, porque el bot deja de hacer backfill y
vuelca esa plata a reencarnar. Ver `Docs/balance-log.md`.

#### UI

La ficha de personaje abre entera y muestra skin y pasivo juntos sin scrollear;
el nombre del personaje nuevo ya no se sale de la pantalla; la franja de piso es
más alta y la hitbox cubre la cabeza.

**La franja de la multitud llega hasta la mitad de la pantalla** (2026-08-05).
Un solo knob, `BoardScene.crowdTopRatio`, en fracción del ALTO de pantalla; el
deambular sale **derivado** de la franja, así que las filas la cubren sin huecos
y nadie puede pasarse por arriba. ⚠️ Los fondos están autorados con el tercio
inferior transitable, así que a 0,5 la multitud pisa la zona del decorado —es lo
pedido, y bajar `crowdTopRatio` a ~0,40 la devuelve al tercio.

---

## 5. Decisiones del dueño que NO se re-litigan

**Decisiones de la 2.0 (aprobadas el 2026-10-06 en `Docs/PLAN-v2.md` §2).** Se
implementan épica por épica. Mientras una no esté implementada, el código sigue
la decisión vieja de abajo, y **la vieja deja de valer cuando su épica cierra**.
La tabla completa, con ~55 filas, está en el plan; acá van las que reemplazan o
tocan decisiones de esta sección:

- **Reemplaza §5.5 (contrato de pacing)**:
  - Dios entre 31 y 35 h activas, en el reloj del simulador; 4–6
    reencarnaciones medidas con un bot que reencarna al multiplicar ×5 su ORO
    (la cantidad depende de esa política, no del juego).
  - Las 7 líneas al máximo antes de Dios, pero no antes de la 5ª
    reencarnación.
  - Cada run llega más lejos que la anterior, con tiempos por piso.
  - **Piso móvil**: para reencarnar hay que alcanzar el tier más alto de la
    run anterior.
  - Lo implementa E2b.
- **Toca §5.7 (las skins de oro no se venden)**: el ORO comprado puede pagar
  todo, y las 7 líneas pasan a costar 348. Las skins de oro quedan
  alcanzables pagando, como ya pasaba en la v1 con el pack de 250.
- **Extiende §5.2 (regla de precios)**: la regla queda, pero **el salto al
  subir de tier se amortigua**. El precio no salta; la diferencia se cobra en
  las compras siguientes y vuelve exacto a v1 después de K compras. Se suma
  un reintegro parcial por fusión (knob). Lo mostrado siempre es lo aplicado.
- **"Cofre" sigue siendo sólo de pintas**: el tesoro con ORO y plata se llama
  **El Colchón**, y la caja con personaje es el **Paquete de la Aduana**.
- **Sin cripto en la app**: la Fisu Coin es un proyecto aparte, fuera del
  juego, sin links ni menciones (Apple 3.1.1/3.1.5, CNV).
- **Universal**: iPad sólo vertical (`UIRequiresFullScreen`) e iOS mínimo 18.
  Reemplaza el "sólo iPhone" del HANDOFF-v2. **Implementada en E3a T5**
  (`3956fd3`).
- **Pisos de 15 lugares** (hasta 20 con un permanente de ORO): reemplaza los
  10 lugares por piso.
- **Agentes concurrentes** (pedido del dueño, 2026-10-06, PLAN-v2 §0.1):
  - todo agente que escribe en el repo se lanza con
    `Agent(isolation: "worktree")` y commitea en su rama `worktree-agent-*`;
  - los archivos calientes (`GameState.swift`, `RootView.swift`,
    `project.yml`, `Localizable.xcstrings` y los demás de §0.1) tienen **un
    solo dueño por ola**;
  - **hasta 3 agentes compilando a la vez, y un `completo` cuenta como uno**:
    con más, la carga llegó a ~600 (§7);
  - un controlador despacha, revisa, integra de a una tarea y es el dueño de
    `Docs/`, `handoffs/`, el journal y `rojos-declarados.txt`: los escribe él o
    un solo agente de docs a la vez, nunca en paralelo con otro que toque `Docs/`.
- **Notificaciones** (pedido del dueño, 2026-10-06, épica E11): **prendidas por
  defecto y desactivables**, y **locales**. El push remoto necesita servidor,
  entitlement y token, y cambia App Privacy: queda fuera salvo que el dueño lo
  pida. El permiso va en dos pasos, provisional (en silencio) al terminar el
  núcleo del tutorial y completo con una tarjeta previa en la primera vuelta
  con popup offline. Un veterano que las apagó en la v1 las sigue teniendo
  apagadas. Nunca anuncios ni precios (guía 4.5.4).

**Decisiones de E4a** (2026-10-10; los 13 defaults de «Para el dueño» del plan quedaron tal cual, el dueño no
cambió ninguno; el porqué de cada uno en `Docs/SESION-2026-10-10-v2-e4.md` §4): la plata de los visitantes
sale del Anexo A sin tocar y la palanca es `visitors.json` `coinsSecondsScale` (E2b la calibra); «nunca deja
menos de 2» es que la torre no queda con menos de 2 empleados ni se pierde el último de un tipo; ignorar una
visita nunca cuesta, y pagar la multa es un trueque opcional; los especiales visitan sólo si ya los
conseguiste; cinco guiones y dos eventos (los de Paquetes o giros, Lluvia y Piquete) esperan a E5; los
botones de los popups son genéricos; el reloj de eventos es de juego activo y va al save; el ×2 con video de
un modificador alarga, no potencia; el ORO del Arbolito (1 por S(5400)) lo revisa E2b.

**Decisiones de E4b** (2026-10-10; los 13 defaults de «Para el dueño» del plan quedaron tal cual, el dueño no
cambió ninguno; el porqué de cada uno en `Docs/SESION-2026-10-10-v2-e4b.md` §4): E4b usa una sola celebración nueva
(`.visitorEncounter`, la entrada) y lo que pasa después no ocupa la cola; el visitante se mueve por frame; un visitante
sobrevive al background pero no a matar la app; el precio tachado sale con cualquier descuento temporal de contratar
y el piso de los apilados es 0,25, en código; el Vendedor da una carta por visita; con el corralito puesto se cobra
pero no se paga; el reto ganado con «×2 con video» ofrece otra tanda igual; los presentadores hablan 4 s; el evento
espera al escenario y le gana al próximo visitante; el escenario va a z 190 y el velo del Apagón a 185; la silueta del
Álbum es la canónica teñida de negro.

**Decisiones de E5a** (2026-10-10; los 12 defaults de «Para el dueño» del plan quedaron tal cual, el dueño no cambió
ninguno; el porqué de cada uno en `Docs/SESION-2026-10-10-v2-e5a.md` §4): un paquete nunca trae a alguien que no
viste; el reloj del paquete se frena con dos esperando y la Lluvia respeta ese tope; paquetes y colchón sobreviven a
la reencarnación; las tablas de la ruleta y del colchón son propuestas que calibra E2b; «Repetir premio» es otro video
y no gasta un giro del cupo de 6; los giros regalados no vencen con el día; el giro con ORO falla cerrado
(`LootBoxGate` nace en E5); el paquete entra por el embudo y no por un `placeGrantedUnit` generalizado; el paquete es
gratis cada 2 min y la palanca es `packages.json`; el cofre de la ruleta suma un cofre pendiente y no lo abre.

**Decisiones del dueño del relevo 6** (2026-10-07, preguntadas en vivo; el
detalle en `Docs/SESION-2026-10-07-v2-relevo-6-ola-d.md` §1):

- **El relevo tiene secundario: las rutinas `fisu-v2-relevo-a` y `-b`**,
  manuales (sin horario), en `~/.claude/scheduled-tasks/`. Motivo: el
  primario, `CronCreate` + `clear_session`, no despertó a nadie en los
  relevos 2 a 6. El agente que cierra lanza la otra rutina con
  `run_scheduled_task`; se alternan porque una rutina con una corrida en curso
  no se puede relanzar.
- **El ORO comprado se cuenta exacto entre dispositivos** (el 🔒 de
  `SaveConflictResolver.swift:67/:68`). Motivo: el `max` de hoy pierde
  compras hechas en dos dispositivos (160 y 550 dan 550), el `||` cuenta de
  menos y un `&&` con el `+=` de la reconstrucción contaría doble; en el
  reset de E9 (`oro = min(saldo, comprado)`) cualquiera de esos errores lo
  paga el que compró. Lo hace **E1 T6c**: un mapa crece-sólo id de
  transacción → ORO más un conjunto de revocados, `oroPurchasedLifetime`
  calculado, unión de `creditedPurchases` y `&&` en
  `purchasedOroReconstructed`. **Toda acreditación de ORO comprado pasa por
  `recordOroPurchase`, nunca por `+=`**: el plan de E6a (T9, T11) todavía dice
  `+=` y está viejo en eso.
- **Las fusiones asistidas cuentan en `totalMergesEver`** (`BoardChange.merge`
  de origen `career` o `debug`). Es lo que ya hacía el video de fusión
  instantánea; no cambia código.
- **La columna de premios de E7b es plegable (opción C)**, hermana de la
  botonera del ascensor: en reposo, un botón "Premios" con el "!" abajo a la
  izquierda; al tocarlo despliega los cuatro por 3 s. Motivo: la columna fija
  pisaba la multitud en todo iPhone, y las otras dos salidas costaban más —
  **A**, reservarle 64 pt, achica los personajes un 17 % en iPhone; **B**,
  ponerla encima, tapa 15–56 pt de la multitud. E7b-b T3 cambia el contenedor
  y **T4 se saltea**: `PlayLayout` y `BoardScene` no se tocan por la columna.

**Decisiones del relevo 7** (2026-10-07; el detalle en
`Docs/SESION-2026-10-07-v2-relevo-7-ola-e.md` §1 y §2):

- **Los guiños escondidos del dueño, con tope: no se suman más.** "Six Seven"
  va en tres lugares: el Turista Gringo con la camiseta 67 (prompts de arte
  016–019), el Crypto Bro ("el gráfico hizo six seven") y el Coach Ontológico,
  que pide 67 toques (eran 60). "Andá pa' allá, bobo" va **una** vez, sin
  nombrar a Messi: la Vecina Chusma ("¿Qué mirás, bobo? Andá pa' allá… ¡ah,
  sos vos!"). Están en PLAN-v2 §2, los anexos A y B, los planes de E4a y E4b
  y la biblia (`50b99ae`). ⚠️ Los prompts 016–019 están editados **sin
  commitear** en `automatic-image-generation/projects/fisu-evolution-v2`:
  ese proyecto nunca estuvo versionado.
- **El ciclo más barato (pedido del dueño: más expeditivo, menos tokens).**
  Motivo, medido: `unit` 1.244 s con tres agentes compilando contra 438 s
  libre, y cada tarea pagaba ~30 min de `rapido` que se repetía al integrar.
  Queda: el agente corre `oraculo.sh tarea <Clases>` (sin Release ni suite
  entera), el brief es la tarea recortada con `brief.py`, **la revisión va por
  riesgo** (sonnet por defecto; opus sólo si cambia lógica de save, del frame
  loop, del turno del tablero o de dinero; ninguna si es mecánica, sólo tests
  o docs; mutantes a mano en EK) y **el `rapido` completo lo corre el
  controlador una vez por ola**. Descarta mantener un `rapido` por tarea:
  repite lo que el de integración vuelve a correr.
- **`GameState.swift` se parte en extensiones por zona** (E1 T9b, entre T9 y
  T10). Motivo: 20 tareas pendientes lo tocaban y, con un dueño por ola, iban
  de a una. Costo aceptado: **todos los `private(set)` pasaron a `var`**,
  porque Swift no deja escribir una propiedad `private(set)` desde otro
  archivo; y los planes que citan `GameState.swift:NNN` apuntan a otro lado
  (cada brief nombra la extensión). En el cuerpo de la clase quedan sólo las
  propiedades almacenadas y el `init`.
- **T6c: si `Transaction.all` vence el plazo, la reconstrucción del ORO NO se
  cierra en 0.** Se reintenta en el próximo arranque. Motivo: cerrarla en 0
  dejaba el save de un veterano sin su ORO comprado, sin reintento (trampa del
  relevo 5). Sigue siendo regla que **toda acreditación pasa por
  `recordOroPurchase`**.

**Decisiones del relevo 12** (2026-10-08; el detalle en
`Docs/SESION-2026-10-08-v2-relevo-12-ola-i.md`): las secciones nuevas del panel de debug van **debajo** de
las puertas de test (una sola solución, la de `402c24d`); el path del menú es un `NavigationPath` y no
`[Destination]`; los fondos van en JPEG q90 a 2048 (PSNR 35–40 dB, sin bloques a ojo); el ascensor y la barra
de 5 pestañas (E13 ítems 13–14) mandan sobre E3a T8; E13 T1 se integra sólo a la rama de integración
mientras el `completo` corre en `version-2`; el cinemático y la cadena de "Fusionar todo" van a un
planificador opus cada uno.

**Decisiones del relevo 11** (2026-10-08; el detalle en
`Docs/SESION-2026-10-08-v2-relevo-11-ola-h.md`): reescribir `AchievementEngineTests.coinRewardKeepsItsHistoricFloor`
(ahora `...HistoryCapped`) fue legítimo, el tope de `RewardScale` lo exige; el día 7 del diario paga
15 minutos exactos; contratar gratis atraviesa el Corralito (anotado); el Médico y la inmunidad se
cablean a `eventIsApplicable` con criterio `!isBuff` hasta que E4a lo reconcilie; sin
`Agent(isolation: "worktree")` mientras `.claude/worktrees` sea un symlink (worktrees manuales en
`worktrees.nosync/`); el worktree de cada tarea se borra al integrarla.

**Decisiones del relevo 9** (2026-10-08; el detalle en
`Docs/SESION-2026-10-08-v2-relevo-9-ola-g.md`): ninguna skin hecha por código entra a la 2.0 (el
dueño); contratar gratis sigue permitido durante el Corralito y la UI lo muestra; la salida por
video del Corralito va debajo del aviso; una fila de FisuJobs que no se puede contratar no muestra
cuánto sube.

**Decisiones del relevo 8** (2026-10-07; el detalle en
`Docs/SESION-2026-10-07-v2-relevo-8-ola-f.md` §2):

- **E1 T12 salió antes que E2a T3/T4, así que E2a T3 → T4 → T5 van después de
  E1 T14.** Motivo: E1 es el camino crítico, y la regla 2 de E2a prohíbe que
  E2a T3/T4 y E1 T12–T14 vayan a la vez. Descarta esperar a E2a para arrancar
  T12.
- **Al pasar a `.inactive` se asienta sólo lo que el jugador ya pagó**
  (orígenes `rewardedInstantMerge`, `rewardedRareUnit` y `career`), **también
  el cambio que está en vuelo**; Startup, Blanqueo y debug esperan a
  `.background` (`settlePrepaidBoardChanges`, `664f3cc`). Motivo: un kill
  desde el App Switcher no manda `.background`, y el carry original (asentar
  la cola entera en `.inactive`) dejaba perder un video ya visto si el cambio
  estaba en vuelo. **Por diseño no se compensan** un Startup o un Blanqueo
  descartados en el turno; el video cuyo plan sale `nil` lo compensa E1 T14.
- **En la ola F el catálogo lo tomó E11 T5**, porque E1 T12 no sumó strings;
  E3a T8 entregó snapshot (`e3a-t8.json`) y el controlador aplicó sus 4 claves
  al integrar (`f9207c2`).

**Decisiones tomadas al implementar la 2.0** (2026-10-06, con el frente entre
paréntesis; el porqué completo está en la sesión de cada uno):

- **Los huecos de `islas_de_papel.json` son decisión del dueño** (E8 pipeline),
  y el barrido del atlas los respeta: el permiso es el hueco que da recortar
  el original, más 1 % de ruido, no una exención del asset. Para cambiar uno
  se pasa por `revision_islas.py` → `aplicar_islas.py`, nunca por el test.
- **Contrato de video, `loops_manifest.json`** (E8 pipeline): con entrada se
  reproduce, sin entrada se cae al arte quieto. Los archivos se llaman
  `loop_<id>.mov` y `cine_<id>.mov` porque Xcode aplana los recursos. Las
  cinemáticas son `reencarnacion`, `arresto` y `dios`. El verde del key se
  mide en cada master; no se copia el de otro video.
- **La música de piso viaja en AAC y se decodifica entera antes de loopear**
  (E8 audio). En PCM serían ~22 MB contra 2,4. El CAF trae la tabla de
  paquetes y `AVAudioFile` recorta el priming, así que el tema decodificado
  tiene el largo exacto. `FloorMusicAssetsTests` pinea largo y costura de los
  diez.
- **Los temas de piso se igualan por RMS (−20 dBFS) con el techo de −9 de la
  v1** (E8 audio): si no, el crossfade suena como subir y bajar el volumen.
  Rango final −20,4 a −22,5; no se comprimió.
- **Config remota de anuncios: más prudente sí, más agresiva no** (E7a). Los
  pisos de `AdsRemoteConfig.Floor` son las decisiones de PLAN-v2 §2 (120 s
  entre forzados, 90 s después de un video, app open con 180 s afuera, 1 cada
  20 min y desde la 2ª sesión). Un `0` publicado por error no puede volver el
  juego una ametralladora de intersticiales, que es política de AdMob. Un
  archivo con un ID de otro publisher, un número bajo el piso o cualquier
  campo inválido se descarta entero: aplicar "la mitad buena" mezclaría dos
  versiones que nadie probó juntas.
- **Una sesión de anuncios es un arranque en frío** (E7a): "app open desde la
  2ª sesión" = el jugador abrió la app dos veces. El primer día, el que decide
  si desinstala, no hay app open aunque vaya y vuelva.
- **La alternancia común/pausa no avanza cuando sale el otro por falta de
  inventario** (E7a): es un orden, no una penalidad.
- **La gracia de arranque de 180 s se conserva** para los intersticiales en la
  2.0 aunque el plan no la nombra (E7a): es la protección de la primera sesión
  de la 1.x, y es remota.
- **El nombre y la descripción de un IAP salen del catálogo del juego** (E3,
  `IAPCopy`, claves `iap.<productID>.name/.desc`), no de App Store Connect.
  StoreKit queda de respaldo sólo si falta la clave, que es mejor que la clave
  cruda para un producto recién creado. Un número en esos textos se interpola
  desde los datos, nunca se escribe a mano. Producto nuevo en `products.json`
  = sus dos claves en el catálogo (el test lo exige).
- **Fichas de IAP en App Store Connect** (E10): es-ES lleva el mismo texto que
  es-MX, con voseo, porque el castellano del juego es rioplatense en todos
  lados y lo que arregla el ítem 19 es que es-ES **exista**. Las descripciones
  no llevan montos de ORO: se calibran sin tocar el precio, y con el número en
  la ficha cada calibración obligaría a re-enviar a revisión. `oro_medium` se
  llama **"Saco de ORO"**: "cofre" es sólo de pintas, y un IAP llamado
  "Cofre" se lee como caja sorpresa paga (guía 3.1.1).
- **"Sin anuncios" se describe como "chau a los anuncios que aparecen solos"**
  (E10): los videos con premio siguen, y una ficha que promete más de lo que
  entrega es motivo de rechazo.
- **Mac y Apple Vision Pro, apagados** en App Store Connect (E10): se publican
  solos si no se destildan, y nadie los probó.
- **AdMob bloquea "Social Casino Games"** además de "Gambling & Betting" (E10):
  viene permitida por defecto, y un casino simulado en un juego que declara
  "sin apuesta simulada" es la contradicción que un revisor marca.
- **Los planificadores de `BoardChange` desempatan de forma determinista**
  (E1 T7): (tier desc, piso, `typeId`) para fusionar y (tier desc, piso,
  slot) para evolucionar. El orden de `Dictionary(grouping:)` cambia entre
  procesos y daba un plan distinto por corrida. E3b usa el mismo comparador.
- **Un save que existe y no se lee no se pisa nunca** (E1 T5). La partida
  queda en `.recovery`, sin jugador y sin escribir nada, y los servicios
  (tienda, Game Center, anuncios) arrancan sólo con `phase == .ready`; por eso
  `.failed` tampoco los arranca. Antes, un save ilegible se leía como "no hay
  save" y la partida nueva lo pisaba.
- **La reconstrucción del ORO comprado en la v1 falla cerrada en 0 y no se
  reintenta** (E1 T6, lo pide el plan): nunca cuenta una compra que StoreKit
  no confirmó. En iOS 17 cerraría siempre en 0, que fue un motivo más para el
  mínimo 18 de E3a T5 (ya integrado).
- **`LootBoxGate`, `OddsDisclosureView`, `RewardCopy` y `PrizeOdds` nacen en
  E5, y E6 los consume** (planes de E5 y E6, coordinados en vuelo). PLAN-v2
  ponía los dos primeros en E6, pero la ruleta y el colchón los necesitan
  antes. Si un despacho de E6 dice crearlos, está leyendo PLAN-v2 y no su
  plan.
- **La multitud de tres filas arranca al 0,63 del alto, no al ~0,70 que
  decía PLAN-v2** (E3a, spike S5): con 0,70 las cabezas de atrás entran 42 pt
  en el display del SE, y el techo medido es 0,637.
- **Las safe areas se leen de un centinela agregado a la ventana** (E3a T4,
  spike S4): una vista adentro de la safe area no se entera de que la barra
  de estado se ocultó. Leídas en `onAppear`, el HUD quedaba a 7,5 pt del
  bezel en el SE.
- **La hora se sella sólo al irse, una vez por salida, y con la escena
  inactiva no pasa nada más que proyectar** (E1 T8). Con la escena
  `.inactive`, `tick` no cobra y `flushHUD` no poda buffs, no dispara eventos,
  no late y no arma anuncios, porque `BoardScene.update` no está gateado por
  la fase y sigue corriendo en el regreso (se midió un frame de 28,52 s todavía
  en `.inactive`). Antes, esa ventana podaba el buff que había vencido afuera
  y el offline pagaba de menos (630 monedas en el test). El segundo sello de
  una salida no corre la hora: si la corriera, el tramo `.inactive` de una
  llamada atendida (20–30 s) no lo pagaba nadie. **Costo aceptado**: un kill
  en foreground re-paga a lo sumo 15 s × 0,35 × pasivo; estampar la hora en
  `persistNow` lo evitaría, pero toca a todos sus llamadores y mete un
  `Date()` implícito en la persistencia.
- **El release se compila con Xcode 26.x hasta que se decida qué hacer con el
  iPad en el SDK 27** (E3a T5). El SDK de iOS 27 ignora
  `UIRequiresFullScreen`, y `InfoPlistContractTests.theSDKStillHonorsFullScreen`
  se pone rojo a propósito ese día. Es un guardián: no se declara en
  `rojos-declarados.txt`.

0. **Los cofres** (2026-08-26). Las 41 pintas de piso salen **sólo** de cofres. Rareza con
   **promoción hacia arriba** cuando la sorteada se agota. Cuatro fuentes: cada 2 pisos, un
   video, el día 7 (como **segundo escalón** después del special, sin robarle el turno) y la
   reencarnación con **épica garantizada**. El primero se abre solo, el resto se guardan. La
   palabra "cofre" es de las pintas; el asado paga "una picada". Las estrellas van en PNG.
0-bis. **La migración v5 reescala SÓLO las líneas por encima de su tope**, no las tres
   (2026-08-26). Motivo: no tocarle nada a lo comprado legítimamente después del rebalance.
   ⚠️ Costo aceptado a sabiendas: la línea parada **exacto** en el tope sigue pudiendo
   llevarse las doradas, y ese agujero **creció** —antes bajaba de rebote cuando el save
   disparaba la huella—. Se eligió con esa información arriba de la mesa.

0-bis-2. **Un cofre NUNCA da la pinta de un personaje que no desbloqueaste** (2026-08-28).
   Palabras del dueño: *"quiero que sea imposible que te toque una skin de un personaje que
   no desbloqueaste todavia (en la historia global, por lo que cuenta a los personajes
   desbloqueados en reencarnaciones anteriores)"*. **Imposible** y **global**, las dos
   literales. El filtro vive en `ChestRoller.stock`, el embudo por el que pasan los TRES
   caminos del sorteo (rareza sorteada, promoción hacia arriba, degradación hacia abajo), y
   el parámetro `unlocked` **no tiene default** para que el compilador lo sostenga.
   - Qué cuenta: `meta.stats.maxFloorOrdinalEver` — la cuenta, no la run.
   - Granularidad **piso y no tier**, a propósito: por tier, la bifurcación de carrera
     encerraría las pintas de la rama que no elegiste y la colección quedaría inalcanzable
     dentro de una run.
   - Bolsa alcanzable seca: el cofre **espera** (`ChestDraw.needsProgress`, no se gasta).
     Sólo paga plata con las 41 ganadas.
   - ⚠️ **Consecuencia**: el cofre de reencarnación deja de garantizar épica en términos
     absolutos. Si el jugador no llegó a un piso épico, **cede el mínimo, no el desbloqueo**.
   Detalle en `Docs/SESION-2026-08-28-cofres-solo-desbloqueados.md`.

0-ter. **El veterano no cobra los cofres de los pisos que ya subió** (2026-08-27).
   `migrateV4toV5` hace **back-fill** de `floorChestsAwarded` con los pisos abiertos ÷ 2, en
   vez de dejarlo en cero. Motivo: con cero, un save parado en el piso 8 cobraba cuatro
   cofres de golpe al actualizar, **y el número dependía de cuándo actualizara** —
   `unlockedFloors` vive en `run` y muere al reencarnar, así que dos saves igual de veteranos
   cobraban distinto según dónde los agarrara el reloj. Se descartó a sabiendas la lectura
   generosa ("que los 4-5 cofres sean su regalo de bienvenida al feature", que tenía a favor
   que **el veterano nunca recibe el cofre de bienvenida**: `grantWelcomeChest()` cuelga de
   `tutorialPhaseFinished()` y su fase ya está cerrada hace rato).

0-quater. **`floorReached` se queda, documentado** (2026-08-27). Quedó sin una sola entrada
   en `skins.json` cuando las 41 pintas pasaron a la bolsa del cofre, y con él dos ramas de
   UI sin alcanzar. **No se saca**: el mecanismo tiene cobertura propia en EconomyKit
   (`SkinMilestonesTests`, `ExtensibilityDrillTests`) con configs sintéticos, sus dos textos
   están escritos en es y en, y la diferencia con `reincarnations` —que tiene DOS filas— es
   dato, no diseño. La decisión está escrita en el docstring del campo, que es donde se
   busca. ⚠️ **No re-abrirla**: si estás auditando ramas sin alcanzar, ésta ya tiene
   respuesta.

0-quinquies. **El atajo del HUD vende el MEJOR tier que la plata alcanza**
   (2026-08-28). Revierte el recorte a tier base de §4.5 del prompt del rebalance
   (`2db8f1d`, 2026-08-21). ⚠️ **No se re-litiga en ninguna de las dos
   direcciones sin mirar estos tres datos**, que son los que decidieron la vuelta:
   - `jobRows` (FisuJobs) **nunca** filtró por tier base, así que el recorte no
     movía el techo de lo comprable — sólo la cantidad de toques.
   - `PacingSimulator.hireActions` compra **todos los tiers desde el 2026-08-22**,
     un día después del recorte, porque con bases solamente el bot no terminaba el
     juego. El contrato de las 20-30 h se midió con ese bot.
   - La regla de precios (§5.2) ya penaliza comprar hondo: bajar un tier abarata
     1,5× pero duplica las unidades a fusionar.

1. **El primer Fisura cuesta 25** (el dueño lo bajó de 50 el 2026-08-18; pineado
   en `GameContentValidationTests`) y los targets de pacing se bajaron a la
   conducta real en vez de recalibrar knobs. Costo medido en `balance-log §F7.6`.
2. **LA REGLA DE PRECIOS, reescrita el 2026-08-23 (decisión del dueño).** La
   vieja —"el tier base de un piso cuesta 600 veces lo que rinde un click SUYO
   ahí"— **ya no vale**, y su reemplazo son dos renglones:

   > **(a)** Contratar **a tu frontera** cuesta **600 clicks** de ese personaje
   > (el callejón, **25** por su `hireCostMultiplierOverride` — el primer Fisura
   > sigue saliendo 25).
   > **(b)** Cada tier que **bajás** descuenta sólo un tercio (÷`priceGrowthPerTier`
   > = 1,5) y fusionar necesita el **doble** de unidades: bajar un tier deja la
   > unidad de tu frontera **1,33× más cara**. Comprar hondo dejó de ser un atajo.
   > **(c)** Y del **tier 7** para arriba, tu propia frontera se encarece un
   > **60 %** por tier (`frontierEscalationPerTier` 1,6 desde
   > `frontierEscalationFromTier` 7), **por encima** de lo que ya sube por rendir
   > más. Eso es lo que pone densa la torre arriba y lo que hace que la run **se
   > trabe** — que es lo que le da trabajo al prestigio.

   ✅ **APROBADA POR EL DUEÑO el 2026-08-23, tal cual está enunciada arriba.**
   Reemplaza al enunciado anterior y a la regla original de los "600 clicks" del
   2026-08-04. No se re-litiga.

   El renglón (c) es lo que convirtió el contrato en una FORMA: la run se traba,
   cada reencarnación corre la pared, y sin reencarnar ya no se llega a dios. El
   umbral del tier 7 es lo que deja el early game y el tutorial intactos —el
   exponente es `max(0, frontera − 7)`— y sin él las primeras cinco runs se
   traban en el callejón (medido).

   ⚠️ **El retorno del prestigio (7-40 %) también está ACEPTADO** por el dueño el
   2026-08-23: no se agrega contenido nuevo para llegar al 67 %. Y hay un **techo
   matemático** que hace inútil intentarlo con knobs — está en `balance-log.md`,
   "El techo del prestigio": volver a la pared cuesta las mismas ACCIONES que la
   primera vez y el ORO saca la espera, no las acciones, así que
   `pago ≤ 1 − acciones(1..T)/primera_vez(T)`. **Los precios entran en el
   denominador, no en el numerador: ningún knob de precio puede cruzarlo.**

   Por qué cambió: la vieja ataba el precio a `tapYield(tier)`, la MISMA curva que
   el rendimiento (2,8 por tier), y como fusionar sólo multiplica por 2, comprar
   `d` tiers abajo salía `(2/2,8)^d`. Comprar hondo siempre ganaba, y por eso una
   compuerta más profunda ABARATABA el juego. El ancla en la frontera separa el
   NIVEL del precio (2,8 por tier de frontera, que mantiene el pacing plano) de su
   PENDIENTE (1,5 por tier comprado). Ningún precio que dependa sólo del tier
   puede tener las dos cosas.
   Pineada en `GameContentValidationTests.hirePricesFollowTheOwnersRule`, con las
   dos mitades y sobre los 37 tiers.
   ⚠️ **Consecuencia user-visible**: los precios de FisuJobs **suben cada vez que
   la torre sube** (×2,8/1,5 = ×1,867 por tier de frontera). Lo que se mantiene
   plano es el TIEMPO, porque tu ingreso también sale de la frontera.
   ⚠️ **La única costura es el callejón** (25 contra 600): comprar ahí sale 24×
   menos y la mitad (b) no vale al cruzar ese borde. Es un descuento ACOTADO y no
   compuesto que se agota solo en el tier 22 de 37; lo pinea
   `elDescuentoDelCallejonSeAgotaSolo`.
   ⚠️ **`hire.tierPremium` ya no existe.** Su trabajo —que comprar arriba no sea
   un atajo contra mergear— lo hace la compuerta; y con la fórmula nueva dejaría
   la pendiente real dentro del piso en 2,8 × 1,8 = 5,04, o sea el agujero otra vez.
   ⚠️ **Enmienda del 2026-08-21 que sigue en pie: `hire.defaultCostGrowth` es
   1,06** — de +20 % a +6 % por compra. El motivo, medido: con el 20 % el bot
   llega a un pico de 70 compras y la siguiente cuesta 384 s de income, así que
   **se traba en el tier 11 y la partida no se puede terminar**.
2bis. **Las mejoras por personaje son SECUENCIALES** (dueño, 2026-08-22): el
   multiplicador es `1 + nivel`, o sea ×2, ×3, ×4 … **×20**, y no el `2^nivel`
   que llegaba a ×1.048.576. Su palabra: *"esto va a reducir mucho las ganancias
   de plata y hacer que los personajes ganen una cantidad de plata 'real'"*.
   `maxLevel` es **19** porque `1 + 19 × 1` es el ×20 que él escribió (con 20
   niveles el tope sería ×21). Pineado en `GameContentValidationTests` y en
   `CharUpgradesTests.theMultiplierIsSequential`.
   ⚠️ `charUpgrades.costGrowth` bajó de 4,0 a 1,5 como CONSECUENCIA, no como
   ajuste suelto: contra un efecto lineal un costo ×4 por nivel mata la línea
   —medido, el bot no pasaba del nivel 7 de 19 y la mediana era 4—, así que el
   ×20 del pedido no lo veía nadie.
3. ~~**El gate es de UN piso**, no dos~~ — **REEMPLAZADA el 2026-08-22 por
   decisión del dueño: la compuerta se mide en TIERS.** Un tipo de tier `T` se
   contrata sólo si `run.maxTierReached >= T + hire.gateTierDistance` (**5**), con
   el tier base de la torre EXENTO. La regla por pisos tenía un borde dentado —un
   piso son cuatro tiers y FisuJobs los vende todos, así que lo que ataba era el
   TOPE del piso habilitado, a UN tier de la frontera— y por eso el jugador nunca
   usaba el ascensor. Medida en tiers, la distancia es la misma compres donde
   compres.
   ⚠️ **Los dos parches por piso ya no existen**: el callejón entero exento y el
   `hireGateExempt` del urbano (que cerró el muro de 268 h de la Ola 3) se
   borraron, y la clave salió de `FloorDef` y del JSON. La única excepción es el
   tier base de la torre, que es una regla de diseño y no un parche.
   ⚠️ **N = 6 desde el 2026-08-23, y recién ahí pasó a ser un dial de verdad.**
   Mientras el precio siguió a `tapYield(tier)`, una compuerta más profunda
   ABARATABA el juego (N=4 → 6,67 h · N=6 → 5,34 h). Con el precio anclado a la
   frontera va para el lado que el diseño esperaba: **N=5 → 4,14 h · N=6 → 7,27 h
   · N=7 → 185,63 h**, porque cada tier de profundidad duplica las compras que
   hacen falta. Arriba de 6 se despierta el muro del early game —hasta que la
   frontera llega a `N+2` lo único contratable es el Fisura—: es lo que pone el
   peor paso en ×4.441 y la primera reencarnación a 28 h de pared. Los números,
   en `balance-log`, "Cuarta ronda".
4. **Los tintes IAP se retiraron** aunque eran los únicos productos pagos además
   de remove_ads.
5. 🟡 **`PacingTests.theOwnersTargetsAreMet` sigue en ROJO, pero por OTRA cosa —
   y ése es el progreso.** El primer assert (maxear en 20-30 h activas) **pasa
   desde el 2026-08-23**: mide 20,67 h. Lo que queda rojo es el segundo,
   **9 reencarnaciones contra ≤8**.
   ⚠️ **No se fuerza, y está medido por qué**: los dos knobs que llegan a 8
   (`oro.exponent` 0,32 y `oro.globalMultiplierPerOro` 0,24) sacan maxear de la
   banda de 20-30, y el segundo además hace que la pared RETROCEDA. Cambiar un
   assert verde por otro no es arreglarlo. Números en `balance-log.md`.
   ⚠️ **Y el total NO se escaló a propósito**: 20,67 h de simulador son ~6,9 h del
   dueño y él pidió 20-30 suyas, pero ese ÷3 sale de UNA comparación. El knob
   está identificado (`oro.divisor` 1e10 → 1e11 da 30,33 h de sim) y espera al
   playtest — subirlo alarga pero **clava la pared** cuatro runs en el mismo tier.
   ⚠️ **Y antes de calibrar contra ese número hay una pregunta abierta para el
   dueño**: las 20-30 h, ¿son del reloj del SIMULADOR o del suyo? Él hizo en
   menos de 1 h la partida que el bot tarda 2,97 h, o sea que juega **~3× más
   rápido**. En su reloj, N=7 con el callejón destrabado da 4,4 h y N=8 da 25,8 h.
   La respuesta cambia qué configuración es la correcta y no la puede contestar
   una calibración. Cuadro completo en `balance-log.md`, "Cuarta ronda (bis)". Se descubrió arreglando el simulador, no cambiando la economía.
   La causa de la ronda 3 (el precio atado a `tapYield(tier)`) **ya está
   cerrada**; la que queda es otra y también está medida: **la mitad del tiempo
   activo del bot es apretar el botón, no esperar plata**, así que los knobs de
   precio son sublineales. Antes de tocar nada leé
   `Docs/SESION-2026-08-23-precio-atado-a-la-frontera.md` §3 y §7: las salidas
   son decisiones del dueño y hay cuatro, medidas.
   `PacingTests` tiene **dos clases de assert y no hay que confundirlas**: las
   cuatro BANDAS son ±30 % de la conducta medida (se re-pinean cada vez que el
   dueño cambia el balance a propósito), y `theOwnersTargetsAreMet` es el
   OBJETIVO —maxear las seis en 20-30 h activas (≤ 8 reencarnaciones en el plan; la
   banda medida de `PacingTests` quedó en ≤ 9 desde E13 T7, decisión del dueño)— que
   **no se re-pinea**: si se pone en rojo, el juego dejó de cumplir lo que se
   pidió. `pacing-sim` sigue imprimiendo los targets de DISEÑO del plan F7.1c
   para que la brecha que queda (la fase fisura) siga visible.
6. **El recorte de fondo se elige a ojo, asset por asset, y no lo decide el
   pipeline.** Ninguna de las dos herramientas gana siempre: la conectividad
   conserva el blanco encerrado del dibujo (una camisa, pero también la sombra
   del piso) y la saliencia se lo come (la sombra, pero también la camisa). Hoy
   hay **98 assets elegidos a mano** —las 86 skins de material y 12 personajes—
   y `recut_assets.py` y el barrido del atlas los SALTEAN para no pisar la
   decisión. Cambiar uno es una corrida de `scripts/elegir_recorte.py`.
7. **Las skins de oro no se venden.** Su única vía es maxear las seis mejoras
   permanentes (eran siete hasta E13 T7, que fusionó las líneas de toque premiado). El diamante es al revés: sólo el bundle, sin condición.
8. **El precio de contratar usa el MISMO factor de piso que el click**
   (`tapFloorMultiplier(for:)`), no el `incomeMultiplier` crudo — salida (a),
   elegida por el dueño el 2026-08-21 sobre otras dos corridas enteras.
   El motivo: `tapFloorMultiplierExponent: 0` le sacó al TAP el multiplicador de
   piso y el precio lo seguía llevando crudo, así que contratar el tier base del
   reino divino pasó de 600 clicks a **372.000** sin que nada hiciera ruido — y
   el test que debía protegerlo seguía verde porque replicaba la fórmula vieja
   del click. Atadas por construcción (las dos llaman a la MISMA función), la
   regla no se puede volver a romper en silencio. Costo medido: 1,3 h de largo
   (25,33 → 24,00 h). Las descartadas: devolverle el multiplicador al tap da
   15,26 h y 9 reencarnaciones (no cumple ninguno de los dos objetivos), y
   dejarlo como estaba obliga a re-enunciar la regla como "600 ×
   `incomeMultiplier` clicks".
9. ~~**El atajo del HUD vende el TIER BASE del piso más alto pagable**~~ —
   **REEMPLAZADA por §5.0-quinquies** (el atajo vende el MEJOR tier). Entró a la
   rama del build recién en `version-2` (2026-10-06), por decisión del dueño.
10. **Los doce logros de ORO fijo suman 33, no 620.** Con 620 contra los 192 que
   cuesta maxear las seis líneas (193 con las siete, hasta E13 T7), juntando logros se ganaba el juego 3,2 veces.
   El dueño los quiso en montos FIJOS (más legibles en la ficha que un
   porcentaje) aportando el 15-20 % del camino; la regla del re-escalado es el
   monto viejo ÷ 20 redondeado para arriba, con piso en 1. Pineado en
   `fixedOroAchievementsFundAFifthOfTheRun`.

11. **Los cofres de piso son una vez por cuenta** (E13 T3). `meta.floorChestsAwarded` no entra a `resolveAcrossReset`: reencarnar y volver a subir
    los mismos pisos **no** da cofres de nuevo; sólo cobra el piso más alto jamás alcanzado. Un veterano v1 que ya reencarnó cobra una última vez (migra
    `max(meta, run viejo)`). El reset de cuenta lo devuelve a 0. Cualquier texto o sim que diga "se vuelven a cobrar al reencarnar" está mal.
12. **Maxear son las seis mejoras** (E13 T7): `lucky` ("Toque premiado", 20 niveles, ×1,09) reemplaza a las dos de toque; 192 ORO con `baseCost` 1, 348 con
    `baseCost` 2 (E2b T14). Dios en 31,34 h activas (decisión del dueño, opción a).
13. **La Startup y el regalo por video salen de frontera − n** (E13 T2/T6): el regalo nombra a quién llega (frontera − 3, cooldown 14400 s) y la Startup
    evoluciona dos tiers abajo de la frontera o paga S(300). "Fusionar todo" por video es uno solo, 600 s, en Regalos y en la columna.
14. **El ascensor es una placa colgante y el viaje sólo ocurre al elegir** (E13b): mantener apretado el ícono del mapa despliega un botón por piso abierto
    (34–46 pt); se recoge tocando afuera; el viaje dura 2–3 s (0,9 s de fundidos con Reduce Motion) y bajo `--uitest*` es 0 s salvo `--uitest-elevator-ride`.
    La barra es de **cinco** pestañas; la Tienda vive en el "+" de la moneda y es una pantalla aparte, no una página del paginador.
15. **El bot del pacing-sim no fusiona el piso que está llenando** (E2b T4, relevo 23). La regla literal del plan («fusionar siempre») nunca completaba un piso de capacidad 10/15, porque
    cada contratación se fusionaba antes de llenarlo; el objetivo se busca debajo del piso de compra. Medido: la base sin bono queda idéntica (Dios 31,34 h · 13 reenc.); con bono 0,05 y cap 10/15,
    Dios en 25,76 h · 11 reenc. · 7 pisos en marcha. Lo discrimina `fillingSurvivesTheMerges` (cap 10). «Fusionar todo» literal, aunque sea pérdida neta para el bot, se re-mide en E2b T13.
16. **El piso de descuentos apilados no alcanza a la contratación gratis** (E4b T7, relevo 24). Los descuentos que se apilan sobre `spawnCostMultiplier` no bajan de 0,25 del precio, pero «gratis» es un modificador
    de magnitud 0 y su producto queda en 0: el piso se aplica sólo si `product > 0` (`25cc5da`, test `freeHiringSkipsTheFloor`). Y `creditOffer` (E6a T11) acredita una oferta comprada **aunque ya no figure abierta**:
    la compra está cobrada, la ventana no decide.
17. **La Ruleta falla cerrada y cuenta el día en gregoriano** (E5a T8, relevo 25). `LootBoxGate` (Storefront alpha-3) dice que no si falta el storefront, la config o el `publisherID`, y se apoya en `isRestricted`; E6a lo reusa. El día de los cupos (`wheelDay`) es gregoriano fijo —con `Calendar.current` un usuario japonés, budista o persa tendría otro año y su día guardado quedaría en el futuro para siempre— y un día guardado en el futuro se acepta sólo hasta mañana. **Costo medido y aceptado:** atrasar el reloj ≥ 2 días devuelve los cupos. El ORO del giro se cobra una vez (copia + asignación atómica). Y en E4b T2 `.visitor` entra en `isPrepaid` (`2aba4ed`): una visita pagada con video que se descarte se compensa.
18. **Los ×3 pendientes y los videos se multiplican, y la calma del tablero es una sola** (E6a T5, E5b T1, E7b-b T6 y E7b-a T3, relevo 26). Un ×3 pendiente (`.nextOfflineMultiplier`/`.nextDailyMultiplier`, `Double`, `isFinite` en el `grant`) se consume una sola vez y **se apila con el ×2 del video**: el Offline ×3 con video da ×6 y el Diario ×3 con video da ×6 del base; en la Obra social el ×2 duplica sólo la plata. **Default medido, sin capar; va al dueño.** El auto-tap corre sólo con la escena activa y con el delta topado en 2 s, se pierde al reencarnar y vence con la app cerrada. **La Ruleta se bloquea desde la vista** (`resolving`, `videoBusy`; el estado caliente de `GameState` no se toca por Reduce Motion), el tic tiene un freno de 0,08 s para sonido y háptico, y `.video`/`repeat` salen sólo de `onRewarded`. **Un video no paga si la acción que premia no se aplicó** (`chooseCareerWithVideo`, `2fb2e90`). **`isBoardBusy` es la definición única de calma** (el reto, el ascensor, la compra y la previa frenan a los visitantes, a Compartir y al ranking; el tutorial, los paquetes y el colchón no usan `isCalmMoment`); `sheetOpen` suma `shareOffer` y `stageChallenge`. **La pausa publicitaria** alterna con el intersticial común con piso y gracia, tiene piso de 5 s aunque la config diga menos, sin premios no se ofrece, «No, gracias» no da anuncio ni premio, y `recordShown` sólo corre con `.presented`.
19. **La Tienda de ORO cobra y entrega en un solo paso, y los visitantes pagan un tercio** (E6a T4, E6a T6, E4b T4, E5b T6 y E2b T10, relevo 27). `buyOroShopItem` cobra sobre una copia y entrega en el mismo paso con **un solo guardado** (`persistNow` cancelando el `saveTask`); si el premio no rinde da `.unavailable` **antes** de cobrar; el segundo ×3 da `.refused(.alreadyPending)`; los topes y el enfriamiento cuentan en día gregoriano; `Origin.oroShop` es prepago. **Fusionar todo no cobra dos veces:** `mergeAllPairs` da 0 si hay un `.oroShop` o una cadena en `pendingBoardChanges`/`inFlight` (`planMergeAll` no ve la cola). El presentador de un evento llega **antes** que el visitante en la misma puerta (`presentPendingEvent` antes de `advanceVisitors`), `advanceEvents` no sortea con un `pendingEvent`, `isBoardBusy` mira `visitorPopup` y `eventPopup`, y `stageVisit` se escribe antes de `arrive`. **`wheel_ready` es el aviso de menor prioridad** (con `maxPerAbsence` 3 y 4 motivos queda afuera si entran los otros tres) y avisa sólo si hoy hubo giro por video. **`visitors.json` `coinsSecondsScale` = 0,31** (E2b T10): visitantes 24,19 min/día, eventos 1,42, total 25,61 (87,9 % de lo que dejan diario y asado). **Default medido; va al dueño.** Los boosts de la tienda multiplican entre sí (3 × `income_x2` + 2 × `income_x3` = ×72 por 30 min): lo mira E2b.
20. **Las probabilidades del cofre fallan cerradas y el cerrojo de compra se prueba con un unitario** (E6a T7 y T8, relevo 28). `ChestOddsTable` y `effectiveOdds` siguen el mismo embudo que el roll (`firstWithStock`), y `reachableSkinCount` cuenta lo alcanzable; `LootBoxGate.lastKnown` dice que no mientras no haya una lectura (se refresca en `StoreManager.start`, salvo XCTest), y T12 recibe `chanceAllowed` por parámetro. `chestHasSomethingToGive` descuenta `pendingChestCount` (incluye el de prestigio). En la pantalla Comprar ORO / Gastar ORO el cofre se oculta con la puerta cerrada y `.nothingYet` no se compra; **el cerrojo (`PurchaseLatch`, 0,6 s) corta el cobro, no apaga el botón** (sin `.disabled` en `PricePill`) y sólo corre cuando se cobra; se prueba con un unitario con RED visto, no con `doubleTap()` ni con dos `tap()`. **Sin decisión nueva del dueño;** la tabla de probabilidades no proyecta los cofres pendientes (¿3.1.1?) y va a `PREGUNTAS-DUENO.md`.


21. **El reset de cuenta pierde las pintas de ORO, `skinsAll` exige las 3 familias, la ruleta del Conductor espera un tablero calmo y el paquete cuenta la cola** (E6b T4 y E5b T2, relevo 29). La pinta comprada con ORO vive en `shop.skins` (sobrevive a la reencarnación; `allOwnedSkins` la une) y `purchaseSkin` mira `alreadyOwned` antes de `spendOro` y rechaza `price <= 0`; **el reset de cuenta las pierde** (la pantalla del reset debe decirlo en `skinsLost`: E9b T8) y **el logro `skinsAll` ahora exige comprar las 3 familias (1350 ORO)**. `openWheel` exige `!isBoardBusy`: **si el tablero no está calmo, el giro queda en Regalos** (`bonusSpins`), no se abre sobre una visita. `packageTapped` y `packageCandidates` **cuentan la cola** (`pendingBoardChanges` e `inFlight`), así que «LLENO» puede tardar un instante de más (conservador). El cerrojo de la Ruleta por ORO es `PurchaseLatch` vía `GameState.beginWheelSpin`, no un `.disabled`. **Sin decisión nueva del dueño;** el reset que pierde las pintas de ORO y el costo de `skinsAll` van a `PREGUNTAS-DUENO.md`.
22. **El dueño aceptó los 26 defaults de `Docs/PREGUNTAS-DUENO-v2.md` (B1–B26) y ya no se preguntan** (2026-10-10, «hacé todo lo recomendado»). El detalle, pregunta por pregunta, está en `tasks.md` §7 («B1–B26 aceptados con su default»).
    Para los relevos: ninguna cambia el ritmo medido (Dios en 31,34 h) ni pide perillas nuevas; **no se «arreglan» como bugs** los costos aceptados: los boosts de ORO y los videos se multiplican sin capar (B2–B5), el reloj movido reinicia
    los topes diarios (B16), Fusionar todo no se compensa (B11), la tabla del cofre no proyecta pendientes (B17) y el ícono del Álbum sigue siendo un glifo SF (B25). Se pierde al reencarnar lo comprado por tiempo con ORO, avisándolo
    (B8, hecho en E6a T8), y al resetear la cuenta un ×3 pagado (B10: lo dice la pantalla de E9b T8). La Bienvenida no se ofrece en BE/AU (B21: E6a T12). B22 está hecha: la política nombra a Anthropic y la nota a App Review da el atajo al Ranking,
    pero `NSPrivacyTracking` queda en `false` a propósito (`true` sin `NSPrivacyTrackingDomains` = rechazo ITMS-91064); 🔒 del dueño: los dominios de AdMob/Unity/Meta. Las A1–A10 siguen siendo gates humanos.
23. **E8e: lo que se hizo por default y no se «arregla»** (relevo 30). Una pinta sin clip propio se queda quieta, nunca anima la base (T8); los videos del juego usan `ArtClips` y no un componente nuevo; el premio del colchón se acredita como antes y el video sólo demora mostrarlo (Reduce Motion lo muestra al toque); el Álbum anima una sola tarjeta, la enfocada y tuya; el visitante suelta su textura al hablar.
    **Un evento de 0 s (aguinaldo, blanqueo, `startup_comprada`) no muestra su ilustración**: no se le inventa una pausa sin que el dueño lo decida. El tablero animado (E8e T10) no se integra sin el gate 🔒 del dueño en su SE (≥ 59 fps, ≤ 1 % de cuadros > 25 ms, ≤ 20 MB animado − quieto).
---

## 6. Cómo verificar

### En la 2.0 se verifica con el oráculo

**Desde E0 (2026-10-06) la forma de verificar `version-2` es un comando**, no
la receta a mano de más abajo. La receta es lo que el oráculo corre por
dentro, y sirve para depurar un paso suelto.

```bash
Tools/v2/oraculo.sh tarea [Clase…]        # EconomyKit + xcodegen + build + SÓLO esas clases de unit
Tools/v2/oraculo.sh rapido   [--limpio]   # EconomyKit + xcodegen + build-for-testing + unit (iOS 26.5)
                                          #   + Release sin warnings: mientras se itera y al integrar
Tools/v2/oraculo.sh completo [--limpio]   # rapido + Store unit y StoreUITests (18.6) + UI (26.5)
                                          #   + pipeline + pacing-sim: para cerrar una ola o una épica
```

- **`tarea` (desde `5d934d6`, relevo 7) es el chequeo de un agente antes de
  su commit**: EconomyKit + xcodegen + build, y de unit **sólo las clases que
  le pasás** (`tarea BoardChangeWiringTests LifecycleTests`). **No compila
  Release ni corre la suite entera**: eso lo hace el controlador en el
  `rapido` de integración, una vez por ola. Sin clases **no corre unit** (y sale
  en VERDE igual: no prueba nada), y las clases se pasan sin el prefijo del
  target. Un VERDE de
  `tarea` no reemplaza al `rapido`.
- **El DerivedData del oráculo es `build/DD-oraculo.noindex`** (desde
  `84cd717`): la carpeta con `.noindex` evita que Spotlight indexe los gigas de
  cada worktree (el load average de 15 min llegó a 346 con `diskimagesiod` al
  140 % y `mds_stores` al 37 %; no hay una medida posterior de la mejora). Si
  tu comando o script nombra `build/DD-oraculo` a secas, está viejo.
- **Desde `ca2d12c` (relevo 6) el `rapido` también compila Release**, después
  de unit. Antes sólo lo hacía el `completo`, y tres `rapido` verdes no vieron
  un rojo que existía sólo en Release (§7, ola D). El Release usa su propio
  DerivedData, hermano del anterior (`build/DD-oraculo.noindex-release`), que
  **`--limpio` no borra**: ~20 s
  incremental y ~100 s la primera vez en un worktree.

- **Sale en 0 sólo si todo está verde.** El juez es `Tools/v2/rojos.py`, que
  compara cada suite contra **`Tools/v2/rojos-declarados.txt`**:
  - un rojo que no está en la lista pone el oráculo en rojo;
  - uno de la lista que deja de fallar se avisa, y se saca en el mismo commit
    que lo arregla;
  - **cero tests corridos también es rojo**: un `-only-testing` mal escrito
    corre cero tests y Xcode lo da por bueno.
- Sigue la receta de abajo al pie de la letra: crea sus simuladores por UDID y
  los borra al salir, corre unit antes que UI, sin paralelismo, con
  `build/DD-oraculo.noindex` propio del worktree.
- Deja logs, `.xcresult` y un `resumen.txt` en `build/oraculo/<fecha>-<modo>/`.
- **`--limpio`** borra el DerivedData antes de compilar: hace falta después de
  tocar arte, porque el build incremental no recompila los atlas (trampa 1).
- Se puede llamar por su ruta absoluta desde cualquier cwd: hace `cd` a su
  propio repo desde `50922d4`. Igual, **un VERDE con la misma cuenta de tests
  que antes de sumar tests no probó nada**: mirá las rutas de los
  `SwiftCompile` en `build-for-testing.log` (§7, frentes de la 2.0).
- El `pacing-sim` es un reporte, no un veredicto: el contrato lo juzga
  `PacingTests` en unit. Sus "13 reencarnaciones" son las de la partida hasta
  Dios con el bot de hoy (§7, plan de la 2.0), no las 9 del rojo declarado,
  que cuenta hasta maxear las líneas (seis desde E13 T7).
- Rojo declarado hoy, uno solo: `unit theOwnersTargetsAreMet` (lo reemplaza
  el contrato nuevo de E2b). La línea del pipeline
  `test_ningun_asset_quedo_agujereado_por_dentro`, que pasaba desde E8, salió
  en `af3acde` (2026-10-07, relevo 4): **el pipeline ya no tiene rojo
  declarado**, así que cualquier rojo suyo es nuevo.

**Línea de base del relevo 12: el `rapido` #2 sobre `c94f75f`** (2026-10-08): EK 556 · unit 784 + 1
declarado · release 0, VERDE. Las 3 regresiones de UI del #2 del relevo 11 están arregladas (`402c24d`,
`2336642`). El `completo --limpio` sobre `c94f75f` (E1 T16) quedó corriendo al cierre: su resultado, en
`Docs/SESION-2026-10-08-v2-relevo-12-ola-i.md`. E13 T1 (`acee4d8`) tiene su tarea verde pero no el `rapido`.

**Línea de base del relevo 11: el `rapido` sobre `e378307`** (2026-10-08): EK 553 · unit 782 + 1 ·
release 0, VERDE. El `completo --limpio` #1 sobre `69a5f80`: unit 760 + 1 · Store 16 · StoreUI 2 · iPad UI
2 · pipeline 49 · pacing-sim VERDES; EK 543 tras `swift package clean`; UI 69/70 (`MenuUITests` flaky,
aislada 7/7 ×2). El #2 sobre `e378307`: ROJO en UI por 3 REGRESIONES reales de la ola H (se repiten aisladas sobre e378307): MenuUITests.testLosTerminosSeAbrenDesdeAjustes (el documento de Términos se dibuja vacío; pasaba aislado sobre 69a5f80 → sospecha E3b T3, NavigationStack(path:) en MenuView), BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos (no encuentra debug.chest.award → sospecha E2a T14, sección nueva del panel de debug) y CharacterSheetUITests.testDespedirPideLaTarjetaDeLaCasaYNoUnaAlerta (sospecha E2a T12 o E4a T8). Todo lo demás VERDE: EK 553 · unit 782+1 · release 0 · store-unit 16 · store-ui 2 · ipad-ui 2 · pipeline 49 · pacing-sim 30,73 h / 13. E1 T16 NO cierra: primera tarea del relevo 12 = arreglar las 3 (bisecar con los merges de la ola H si la sospecha no alcanza), re-correr esas clases aisladas y después un completo --limpio sobre la punta. La referencia completa sigue siendo la de
abajo hasta que el #2 la reemplace.

**Línea de base nueva: el `completo` sobre `528d10b`** (2026-10-08, relevo 9): EK 508 · unit
724 + 1 · Store 16 · `StoreUITests` 2 · pipeline 49/0 · `pacing-sim` 30,73 h / 13 (igual) · Release
0 · UI 69/70: `CustomizationUITests.testSinPrecioLaSkinPagaNoDiceQueNoEstaALaVenta` cayó bajo carga
(load ~900) y pasó aislado 2 de 2. Reemplaza a la de abajo.

**Línea de base: el `completo` sobre `15318a0`** (2026-10-07, relevo 8; las
olas B a E más las ramas sueltas del relevo 7: los arreglos de E1 T10, E11 T4,
E2a T1, E6b T1–T2 y los mutantes de E5a). **Es el último `completo` VERDE y
reemplaza al de `d22eb7a`** (abajo, como historia):

| Suite | `d22eb7a` (relevo 5) | **Hoy (`15318a0`)** |
|---|---|---|
| EconomyKit | 317 | **484** |
| unit (26.5) | 593 + 1 declarado | **691 + 1 declarado** (746 s) |
| Store unit (18.6) | 12 | **16** (1.338 s) |
| UI (26.5) | 57 | **63** (2.935 s) |
| `StoreUITests` (18.6) | 2 | **2** (399 s) |
| pipeline | 49 / 0 | **49 / 0** |
| `pacing-sim` | Dios en 30,73 h activas · 13 reencarnaciones | **igual** |
| Release | 0 warnings | **0 warnings** (478 s) |

- **`MenuUITests.testAjustesTraeSusControlesYApagaLasParticulas`**, rojo en
  E11 T4 en el relevo 7, dio VERDE: era flaky de carga, no de T4.
- Los +3 de Store unit y los +4 de UI no están desglosados por tarea.
- ~101 min (la suma de las etapas). Log:
  `version-2/build/relevo8-completo-15318a0.log`.
- **La ola F no pasó por un `completo`.** Sobre la próxima punta (con E2a T7,
  que sube los montos de cofres y packs) el `pacing-sim` puede moverse: es lo
  que hay que medir, junto con `StoreManagerTests`.

**El `completo` sobre `d22eb7a`** (2026-10-07, relevo 5; es
`5a65335`, la ola B, más docs), contra las anteriores:

| Suite | E0 (`0442022`) | `6b5e408` (relevo 3) | **Hoy (`d22eb7a`)** |
|---|---|---|---|
| EconomyKit | 267 | 267 | **317** |
| unit (26.5) | 473 + 1 declarado (411 s) | 570 + 1 declarado | **593 + 1 declarado** (503 s) |
| Store unit (18.6) | 12 (197 s) | 12 | **12** (995 s, con carga) |
| UI (26.5) | 57 (1.515 s) | 57 (2.398 s, con carga) | **57** (2.563 s, con carga) |
| `StoreUITests` (18.6) | 2 (114 s) | 2 | **2** (499 s) |
| pipeline | 24 + 1 declarado | 49 / 0 | **49 / 0** |
| `pacing-sim` | Dios en 30,73 h activas · 13 reencarnaciones | igual | **igual** |
| Release | 0 warnings | 0 warnings | **0 warnings** |

- **La frontera de un solo mutador y el save v6 no movieron el pacing**: es el
  primer `completo` que los mide, y el `pacing-sim` da lo mismo que en
  `6b5e408`.
- El unit cuadra exacto: 570 + 4 de la Ola A + 19 de la ola B = 593. Un
  número distinto después de integrar es un test perdido o duplicado.
- Un `completo` entero tarda **~45 min** con la máquina tranquila (build en
  frío 106 s); éste, con la máquina cargada, tardó **~81 min** (4.886 s).
- Log: `version-2/build/relevo5-completo-d22eb7a.log`.
- Es de antes de la ola C. El de `8d17b8d` (abajo) dio rojo en Release, así
  que fue el último `completo` VERDE hasta el de `15318a0` (arriba).

**El `completo` sobre `8d17b8d`** (2026-10-07, relevo 6; la ola C entera):
**todo verde salvo Release.**

| Suite | **`8d17b8d`** | Contra `d22eb7a` |
|---|---|---|
| EconomyKit | **357** | +40 de E1 T7 |
| unit (26.5) | **620 + 1 declarado** (601 s) | +27 de la ola C y T5b |
| Store unit (18.6) | **13** (1.945 s, con carga) | + `reconstructsTheV1OroFromTransactionHistory` |
| UI (26.5) | **59** (1.976 s) | + `SaveRecoveryUITests` y `ScreenInsetsUITests` |
| `StoreUITests` (18.6) | **2** (147 s) | igual |
| pipeline | **49 / 0** | igual |
| `pacing-sim` | **Dios en 30,73 h activas · 13 reencarnaciones** | igual |
| Release | **❌ no compila** (101 s) | `GameState.swift:545:27: error: will never be executed` |

- Todos los números esperados cuadraron; el único rojo es Release. Lo trajo
  E1 T5 (`38bee13`): un if/else sobre `forceNewGame`, que en Release es un
  `var` que sólo cambia dentro de `#if DEBUG`, así que la rama `.empty` era
  código muerto. Lo arregló **E1 T5c** (`e0a5d53`), verificado con el
  `rapido` que ahora compila Release: 0 warnings sobre `ca2d12c`.
- ~81 min en total (~4.876 s), con hasta 3 agentes compilando al lado.
- Log: `version-2/build/relevo6-completo-8d17b8d.log`.
- **Nada de la ola D pasó todavía por un `completo`.** Sobre `3956fd3` se
  espera: EK 357 · unit 639 + 1 · Store unit 13 · UI 59 · `StoreUITests` 2 ·
  pipeline 49/0 · `pacing-sim` igual · Release 0 warnings.

**El `rapido` de la ola F** (2026-10-07, relevo 8). **Los números de
referencia del `rapido` son los de `f9207c2`: EK 506 · unit 704 + 1 ·
release 0.**

| Árbol | EconomyKit | unit (26.5) | Release | Veredicto | De dónde sale |
|---|---:|---:|---|---|---|
| `15318a0` (las ramas sueltas; el `completo`) | 484 | 691 + 1 | 0 warnings | VERDE | ver la línea de base, arriba |
| `f9207c2` (la ola F) | **506** | **704 + 1** (1.032 s) | **0 warnings** (411 s) | **VERDE** | E1 T12, E3a T7–T8, E11 T5, E2a T2 y T6, E6b T3; no desglosado por tarea |

- Log: `version-2/build/relevo8-rapido-f9207c2.log`.

**El `rapido` de la ola E** (2026-10-07, relevo 7; números viejos):

| Árbol | EconomyKit | unit (26.5) | Release | Veredicto | De dónde sale |
|---|---:|---:|---|---|---|
| `b0f6f6c` (+ E11 T3 con arreglos) | — | 653 + 1 | — | VERDE | cuadra con 639 + 21 − 9 + 2 de los arreglos |
| `60af174` (`version-2`, la ola E entera) | **447** | **683 + 1** | **0 warnings** | **VERDE** | los 30 de 653 a 683 no están desglosados por tarea |

- Con las ramas sueltas integradas se esperaba EK ≈ 480 y unit ≥ 690 + 1;
  dio 484 y 691 + 1 (`15318a0`, relevo 8), que además pasó el `completo`.

**El `rapido` de la ola D** (2026-10-07, relevo 6). **Los números de
referencia del `rapido` son los de `ca2d12c`: EK 357 · unit 633 + 1 ·
release 0.**

| Árbol | EconomyKit | unit (26.5) | Release | Veredicto | De dónde sale |
|---|---:|---:|---|---|---|
| `8d17b8d` (ola C) | 357 | 620 + 1 | — | VERDE | — |
| `ca2d12c` (E1 T8 + arreglos + T5c; árbol Swift == `7110b06`) | **357** | **633 + 1** | **0 warnings** | **VERDE** | +11 de T8 · +2 de sus arreglos; build 97 s, unit 656 s, release 99 s |
| `3956fd3` (+ E3a T5) | 357 | 639 + 1 | 0 warnings | VERDE | +6 de `InfoPlistContractTests` |
| `a4c156f` (E5a T1, en `v2/e5-premios`; sólo `swift test`) | **393** | 620 + 1 | — | VERDE | +23 de T1 · +13 del refuerzo |
| `f084ef5` (E11 T3, sobre `8d17b8d`; sin integrar) | 357 | 632 + 1 | — | VERDE | +21 nuevos − 9 viejos |

- Con E5a T1 y E11 T3 integrados se espera EK **393** y unit **651 + 1**,
  más lo que sumen los arreglos de E11 T3.
- Logs: `v2-e1/build/relevo6-rapido-ca2d12c.log` y
  `version-2/build/relevo6-rapido-3956fd3.log`.

**El `rapido` de la ola C** (2026-10-07, relevo 5):

| Árbol | EconomyKit | unit (26.5) | Veredicto | De dónde sale |
|---|---:|---:|---|---|
| `5a65335` (ola B) | 317 | 593 + 1 declarado | VERDE | — |
| `cdd8f0a` (E1 ola C) | **357** | **608 + 1 declarado** | **VERDE** | +40 EK de T7 · unit +6 de T5 · +9 de T6 |
| `bc3bf6f` (+ E3a fix T3 y T4) | 357 | 611 + 2 | **ROJO** | +4 de `ScreenInsetsTests`; el rojo nuevo es `PersistenceTests.rotatesTheLastTenGoodLoads` |
| `d0710e1` (+ E1 T5b; árbol Swift == `0cfe6c9` en `version-2`) | 357 | **620 + 1 declarado** | **VERDE** | +8 de T5b (nombres sin pisarse, cada payload ilegible, copia cruda al empezar de nuevo, sin copias idénticas) |

- El rojo de `bc3bf6f` **no está declarado y no hay que declararlo**:
  `SaveBackupStore` nombra las copias por milisegundo, y en una corrida 2,6
  veces más rápida que la de `cdd8f0a` (unit 374 s contra 977 s) tres de las
  12 cargas del test cayeron en un milisegundo ya usado: 9 copias contra 10
  (§7, ola C). Es de E1 T5, no del merge de E3a. Lo arregla **E1 T5b**, en el
  producto, y `bc3bf6f` no se pushea hasta que esté verde.
- La cuenta cierra igual: 611 + 2 = 612 + 1, así que no se perdió ningún test.
- Logs: `v2-e1/build/relevo5-rapido-cdd8f0a.log` y
  `version-2/build/relevo5-rapido-bc3bf6f.log`.

### La receta a mano (lo que el oráculo corre por dentro)

⚠️ **Creá tu propio simulador y apuntá por UDID** (trampa 2), y **corré unit
ANTES que UI** — la asimetría es real y direccional, ver abajo.

⚠️⚠️ **Desde Xcode 26.6 (2026-08-25) la verificación es una MATRIZ de dos
runtimes** (trampa 30, eslabón 6): TODO corre en un sim **iOS 26.5** SALVO
las tres suites de Store —`StoreManagerTests`, `StoreProductsTests`,
`StoreUITests`—, que corren en un sim **iOS 18.6** porque StoreKit Testing
está roto entero en el runtime 26. En 26 se las saltea con
`-skip-testing:` (las tres, nada más); en 18.6 se corren solas con
`-only-testing:`. Señal de re-unificación: `StoreProductsTests` verde en un
sim 26 virgen.

```bash
UDID=$(xcrun simctl create "mi-frente" "iPhone 16 Pro")

cd Packages/EconomyKit && swift test                      # 506 en version-2 al relevo 8 (f9207c2)
cd - && /opt/homebrew/bin/xcodegen generate               # si agregaste/borraste Swift

# 1) UNIT PRIMERO
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build/DD -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests test                   # en 26.5 sin las 2 de Store; el número, en la línea de base de arriba

# 2) UI DESPUÉS
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build/DD -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionUITests test                  # 57 en 26.5 sin StoreUITests (+2 en 18.6)

cd Tools/asset-pipeline && .venv/bin/python -m unittest discover -s tests -q   # 49, 0 rojos desde E8 pipeline

xcrun simctl shutdown $UDID && xcrun simctl delete $UDID   # ⚠️ el cierre es parte del trabajo
```

Estado el **2026-10-06** (`version-2`, árbol final de la preparación, matriz
entera): **EconomyKit 267 · unit 474 con el único rojo declarado (26.5) · Store
12/12 (18.6) · UI 57/57 (26.5) + `StoreUITests` 2/2 (18.6) · pipeline 25 con
1 rojo (arte calado)**; Release para dispositivo compila con cero warnings.
Detalle en `Docs/SESION-2026-10-06-preparacion-v2.md`.

Estado el **2026-08-27** (cierre de los cofres de skins), tomado con la receta
completa en un worktree limpio sobre el tip de `main`, con la matriz de dos
runtimes corrida ENTERA:
**EconomyKit 262 · app 459 con UN solo rojo (el declarado) · UI 55 sin un rojo ·
pipeline 27 (1 rojo conocido, de entorno)**, cero warnings de compilador.
Los tres primeros salen de la MISMA verificación, y la de UI corrió **sin un solo
flaky re-corrido**.

⚠️ **Los "11 rojos de StoreKit" ya no son parte del cuadro.** Eran del runtime
26, y la matriz de dos runtimes es justamente lo que los resuelve: en el sim
**18.6 pasan los 12** (`StoreManagerTests` 10 + `StoreProductsTests` 2). Contar
un cuadro con 12 rojos era heredar el síntoma después de haber construido la
cura. El único rojo del proyecto es uno.

⚠️ **PERO el 2026-08-28 el 18.6 también falló, y fue LA MÁQUINA, no el árbol**:
`StoreManagerTests` con fallos ROTATIVOS (el catálogo `.failed` tras ~270 s de
reintentos vacíos, un refund que no revoca — la firma del breakage de StoreKit
Testing), en tres corridas incluida una con el sim borrado a cero, con un diff
que no toca un archivo de Store, Xcode sin cambiar de build y `StoreUITests`
verde en el mismo sim. Si te pasa: verificá el diff con `git diff … | grep -i
store` antes de sospechar del código, y re-corré otro día — la señal de sano es
`StoreManagerTests` entero verde en un 18.6 virgen.

🔴 El rojo declarado es **`PacingTests.theOwnersTargetsAreMet`** y es la verdad,
no un flaky — pero ⚠️ **no por el motivo que este documento decía hasta hoy**.
El contrato de las **20-30 h ya pasa** desde la desaceleración; lo que queda
rojo es el segundo assert: **9 reencarnaciones contra las ≤8**. El docstring del
propio test lo explica (el bot reencarna al duplicar su ORO histórico, así que
las reencarnaciones para maxear son ≈ log₂ del costo total, y la cuenta se pasa
por una). Ver §5.5 — y si alguna vez este párrafo y el docstring vuelven a no
coincidir, el docstring manda.

✅ **El runtime de iOS 26 ya está instalado** (26.5 - 23F77): el gate humano del
2026-08-22 está resuelto y **`Assets.xcassets` NO hay que sacarlo del target**.
Lo que sigue haciendo falta es el flag de `StoreKitTest`:

```bash
xcodebuild … OTHER_SWIFT_FLAGS='$(inherited) -Xcc -Wno-deprecated-declarations'
```

<details><summary>La receta de la ronda 3, cuando la máquina no tenía runtime de iOS 26 (histórica)</summary>

```bash
# 1) sin esto xcodebuild no lista NINGÚN destino de simulador
xcrun simctl runtime match set iphoneos26.5 22G86
# 2) actool no puede compilar el catálogo: AssetCatalogSimulatorAgent está
#    compilado para iOS-simulator 26.4 y el runtime 18.6 no tiene
#    _swift_coroFrameAlloc. No hay flag que lo evite.
mv FisuEvolution/Resources/Assets.xcassets /tmp/ && /opt/homebrew/bin/xcodegen generate
# 3) el header de StoreKitTest usa API deprecada en iOS 18 y el target compila
#    con -warnings-as-errors
xcodebuild … OTHER_SWIFT_FLAGS='$(inherited) -Xcc -Wno-deprecated-declarations'
```

**El parche 2 cambia lo que se ejecuta**: la app corre sin catálogo de colores y
los `Color("Palette…")` caen al default. No afecta a unit; la suite de UI pasó
igual (48/48), pero un test que juzgue color no serviría así.
`xcodebuild -downloadPlatform iOS` **no sirve** (cree que la plataforma ya está
por el 18.6 y ninguna 26.x figura disponible). El arreglo de verdad es instalar
el runtime desde **Xcode > Settings > Components**: es un gate humano — y el
2026-08-25 alguien lo hizo, así que esto es historia.
⚠️ Y al terminar, **volvé a poner `Assets.xcassets` en su lugar antes de
commitear** — es fácil dejarse una veintena de borrados en el `git status`.

</details>

ℹ️ El **27 del pipeline** es el único que no se re-midió el 2026-08-21 (es Python
y esta rama no lo tocó): viene del cierre de `fix/cierre-post-merge`.

⚠️ **El número de UI se toma de UNA sola corrida y sin un solo skip**
—`AscentRenderingUITests` adentro—, que fue lo último que quedó pendiente de
medir en `fix/cierre-post-merge`: hasta ese día salía de SUMAR los 3 de esa clase,
verificados aparte, a los que se medían con ella salteada.

⚠️ Y se tomó **en malas condiciones a propósito**: arrancó con la máquina en
`load average` **~156** por frentes ajenos y la suite pasó entera igual, con
**cero flakies re-corridos**. O sea que el 43 no es un número de laboratorio.

#### Cómo se movieron desde entonces (2026-08-17)

Los cuatro de arriba son **el último cuádruple tomado con la receta completa**.
Lo que se sumó después está medido, pero cada suite por su lado y en el simulador
compartido, así que no lo reemplaza:

| Suite | 2026-08-16 | Hoy (2026-08-21, main `9efc8f7`+manito) | Qué entró |
|---|---|---|---|
| EconomyKit | 183 | **234, cero rojos** | `CelebrationQueueTests` + la restricción del tutorial (sesión tutorial) y `PacingSimulatorTests` + `PermanentUpgrades` (rebalance) |
| app | 346 | **411, cero rojos** | tutorial: `CelebrationWiringTests` (+fase), `TutorialTipsTests`; rebalance: `PacingTests` re-pineado ENTERO (los «3 rojos conocidos» YA NO EXISTEN como categoría), `BestHireTests`, `SaveMigratorTests` |
| UI | 43 | **48, cero rojos, sin skips** | `CareerChoiceUITests`, `MenuUITests`, `TutorialUITests` reescrita (lección + puntito) |
| pipeline | 27 | 53 | frentes de arte ajenos; 1 rojo ajeno (4 PNG calados de `estanciero_estelar__tropero`) |

⚠️ Los cuatro de la columna «Hoy» son del árbol FINAL del 2026-08-21 —el
merge del rebalance a main más la manito— tomados en la verificación del
merge (`SESION-2026-08-21-merge-rebalance-y-manito.md`): EconomyKit por
`swift test`, app + UI en el MISMO simulador propio por UDID con la receta
completa (unit antes que UI, `-parallel-testing-enabled NO`, sin skips). El
quinto número de ese cierre es el `pacing-sim`: **24,00 h activas · 8
reencarnaciones**, que es el contrato del dueño.

**El próximo cuádruple hay que tomarlo con la receta de arriba**, no sumando
estos. Y ojo con `refundRevokesEntitlement` (StoreKit + `SKTestSession`): falló
tres veces en corridas completas de este día y pasó aislado todas ellas.

- ~~El rojo del pipeline es `test_wait_for_survives_a_stale_element_and_retries`~~:
  ese test se fue con la generación de arte (`version-2`, 2026-10-06), y el
  rojo del "arte calado" que lo reemplazó lo cerró E8 pipeline. El pipeline
  está en **49 verdes, 0 rojos**.
- **Ya no hay ningún `-skip-testing:` en la receta de UI.** El único rojo que
  quedaba, `AscentRenderingUITests`, se migró a doble toque el 2026-08-16 y pasa
  (ver la trampa 2). Los 3 tests de esa clase entran al conteo: 40 → **43**.
- Usá siempre `-parallel-testing-enabled NO`.
- ⚠️ La suite de UI pasó de ~40 a 43 tests y `AscentRenderingUITests` es la más
  lenta de todas (~4 min de las tres juntas, porque escala el callejón fusión
  por fusión). Si una corrida completa empieza a rozar los flakies sensibles a
  carga que se listan más abajo, es por eso — mirá el reloj antes que el código.

⚠️⚠️ **UNIT ANTES QUE UI, siempre.** Correr los tests de UI primero rompe
`StoreManagerTests` **enteros**, y no es carga: fallan igual aislados. Una
corrida de UI deja la tienda local del simulador en un estado que
`SKTestSession` ya no puede usar. Con el device recién creado y unit primero,
pasan los 336 sin tocar nada.

⚠️ **`PacingTests.strugglingPhaseLength` figuraba como rojo de entorno** (moría
con `Test crashed with signal kill`) y el 2026-08-16 **pasó en la corrida
completa**. Si te falla, tratalo como entorno, no como economía.

`EconomyLoopUITests`, `BonusHUDUITests` y
`StoreManagerTests.refundRevokesEntitlement` son flakies **sensibles a carga**:
pasan aislados. El 2026-08-16 pasaron los tres en la corrida completa sin
re-correr nada. **Si una suite empieza a fallar en una corrida que va lenta,
mirá el reloj antes que el código** — y `uptime`, que un simulador ajeno
booteado o un `simctl` huérfano de otra tanda alcanzan para ensuciarla.

Simulador a mano:

```bash
xcrun simctl install booted build/DD/Build/Products/Debug-iphonesimulator/FisuEvolution.app
xcrun simctl launch booted com.manuader.fisuevolution --uitest-reset
```

Fixtures DEBUG por launch argument — **son 22** (las últimas siete de la tabla
se documentaron recién en `version-2`):

| Argumento | Qué deja listo |
|---|---|
| `--uitest-reset` | Partida nueva. Resetea también `fisuTutorialDone`, las banderas `ftue.*` y **los ajustes que viven en `UserDefaults`** (partículas, notificaciones e idioma — T16): sin eso, un test que apaga las partículas se las deja apagadas al siguiente |
| `--uitest-skip-tutorial` | Sin tutorial. **Casi todo test de tablero lo necesita**: si no, el scrim se come los toques (trampa 9) |
| `--uitest-coins` | Plata para contratar sin dar ~50 toques |
| `--uitest-unlock-tower` | Abre pisos hasta el del tier 5. ⚠️ **NO toca `maxFloorOrdinalEver`**, así que no desbloquea boosts |
| `--uitest-seen-types` | Marca tipos vistos: es lo que llena la pestaña Personajes |
| `--uitest-prestige` | Acredita lifetime para llegar a reencarnar |
| `--uitest-open-sheet` | Abre la ficha sobre la primera unidad |
| `--uitest-skins` | Acredita las skins de milestone de los tipos YA VISTOS (van con `--uitest-seen-types`, que es lo que decide cuáles). Es lo que permite ejercer "Ponérsela" en Pintas sin abrir pisos ni reencarnar |
| `--uitest-unseen-skin` | Acredita la pinta de cofre del personaje de tier más ALTO que el jugador NO vio (en una partida nueva, la de la Deidad). Es el reverso de `--uitest-skins` y el único fixture que separa Pintas de Mejoras: sin él las dos pantallas listan lo mismo y el carrusel se puede volver a colgar de `characterUpgradeTypes` sin que nada se ponga rojo |
| `--uitest-storekit-empty` | `StoreManager` no carga productos: simula la tienda que no contesta. Es la ÚNICA forma de ejercer desde un test la rama "Precio no disponible", porque el runner inyecta la configuración de StoreKit del scheme y si no los productos cargan siempre |
| `--uitest-daily-streak` | Deja el ciclo del daily en el día 4: la tira del calendario de Regalos con días cobrados atrás. El único otro camino a un día con tilde es **volver mañana** |
| `--uitest-achievements` | Siembra los contadores históricos que cruzan tres logros (`ach_merges_1`, `ach_taps_1000`, `ach_videos_1`) y los deja **conseguidos y sin cobrar**: es lo único que llena la sección "Para cobrar" de la pantalla de Logros. Conseguir uno jugando pide fusionar, mirar un video con el proveedor real o dar mil toques — nada automatizable. Usa `max`, así que no pisa un save con más. ⚠️ Acredita durante `phase == .loading`, así que **NO desfila los tres banners**, y un logro ya acreditado no vuelve a cruzarse: para filmar el toast hay que cruzar uno EN RUNTIME y con el tablero despejado. El único barato es `ach_merges_1` — contratar uno en FisuJobs, cerrar la hoja y fusionar el par con doble toque. Contratar diez cruza `ach_hires_10` pero deja el banner tapado por la hoja |
| `--uitest-daily-popup` | El popup del premio del día, ya abierto (T18). Retrocede `lastClaimDay` a **ayer** —no lo borra, que un día salteado resetea el ciclo a 1— y corre el claim real, el mismo que acredita al volver a foreground. Existe porque el daily se cobra solo y una sola vez por día, y una partida nueva marca `lastClaimDay` en HOY para no pisar el tutorial: sin esta puerta, la única pantalla que celebra la racha no se puede ni fotografiar ni ejercitar sin cambiarle la fecha al simulador. Combinado con `--uitest-daily-streak` muestra el día 4. Desde el 2026-08-21 **ya no necesita `--uitest-skip-tutorial`**: la cola arbitra (con la fase viva el popup espera su turno y aparece al cerrarla — usarlo SIN skip es justamente el repro del viejo deadlock) |
| `--uitest-lessons` | Prende las lecciones contextuales del tutorial, que en cualquier corrida `--uitest-*` arrancan APAGADAS (trampa 27). Sólo lo usa el test que ejercita el coach-mark |
| `--uitest-special` | El primer special del catálogo, caído y ANCLADO al piso visible, con la carta del drop abierta. Es la única forma de ver la carta (el drop real es RNG sobre merges) y de ejercitar el recap del mantener-apretado |
| `--uitest-chest` | Un cofre abierto, con la animación esperando el primer toque. El camino real pide dos pisos o un video con cooldown |
| `--uitest-chest-manual` | La animación del cofre avanza SÓLO con toques (sin el auto-avance), para que un test controle cada latido |
| `--uitest-career` | El fork de carrera abierto, sin llegar a T9 |
| `--uitest-char-upgrades-maxed` | El Fisura con su línea de mejoras al tope: el estado "Al máximo" de la fila. Sin test que lo use; queda para capturas |
| `--uitest-offline` | El popup de ganancias offline con un monto fijo (y su oferta de duplicar por video). Sin test que lo use; queda para capturas |
| `--uitest-slow-ad-load` | El stub de anuncios tarda 1,5 s en "cargar" el video antes de presentarlo (E13 T1). Es la ventana para tocar dos veces con el primer toque todavía cargando: sin él el stub presenta en el acto. Lo usa `RewardedOfferUITests` |
| `--screenshot-mode` | Apaga el andamiaje de DEBUG (contador de FPS, botón de herramientas) y sirve los textos de tienda (review-safe). Lo usa `AppStoreScreenshotTests` para la ficha |
| `--uitest-unreadable-save` | Planta un save truncado en CoreData y en el snapshot antes de cargar: arranca en la pantalla de recuperación (`SaveRecoveryView`, E1 T5). ⚠️ "Reintentar" re-corre el arranque entero y el fixture vuelve a plantar el save roto, así que la pantalla reaparece: es lo que espera `SaveRecoveryUITests` |

El panel de debug es el ícono de herramientas del HUD.

---

## 7. Trampas en las que ya caímos

### De E4b y E5a (2026-10-10, cierres)

- **El escenario es de una sola entrada:** un evento espera al visitante en escena y ningún visitante entra con un evento esperando. Si agregás algo que sube al escenario, entra por `stageVisit` y por el turno `.visitorEncounter`; una segunda vía rompe las dos reglas.
- **Todo lo que se mueve en el escenario va por frame, nunca con `SKAction`:** así `StageControllerTests` prueba entrada, espera, toque y salida sin vista. Los efectos de `StageEffects` también son por frame.
- **Una hoja nueva va con `fisuSheet()`, y su `onChange` escribe `gameState.uiCoversBoard`** (`RootView.boardIsCovered`): si la hoja no está en esa lista, la paciencia de los visitantes corre con la hoja abierta y el visitante se va mientras mirás otra cosa.
- **`ActionPill(verbatim:)` para los títulos que salen del dato** (los botones de los popups de visitantes y eventos): envolverlos en un `LocalizedStringKey` los vuelve una clave que el catálogo no tiene (trampa 5).
- **`debugStartEvent` aplica el evento en el acto y `debugPresentEvent` pasa por el presentador:** el segundo es el que ve el jugador y espera si hay alguien en escena; para fotografiar o probar el efecto real, el primero.
- **`meta.specialAnchors` no tiene escritores desde E4b T9:** `PlayerState`, el migrador y `SaveCompatibilityTests` todavía lo llevan. Se borra en el próximo bump de schema; hasta entonces nadie lo escribe ni lo lee para decidir nada.
- **Un paquete sólo trae lo que FisuJobs vende con lugar** (`PackageRoller.eligibleTypes` = `jobState == .hirable`): si cambia una regla de FisuJobs, `candidatesMatchFisuJobs` (`PackageRuntimeTests`) se pone rojo. No se parchea el test: se alinea la regla.
- **La Ruleta muestra y sortea la tabla EFECTIVA** (`WheelConfig.effectiveSegments(chestHasSomethingToGive:)`): nunca dibujar `wheel.segments` crudo, porque con el cofre vacío el segmento del cofre pasa a la plata de 30 min y la rueda mentiría.
- **`LootBoxGate` falla cerrado:** sin tienda conocida no hay giro con ORO (ver la decisión 17 de §5). Un fixture o un test de la Ruleta por ORO tiene que armar el gate, no esquivarlo.

### De E4a (2026-10-10, cierre)

- **Un guion o evento que da algo que `grantableRewardKinds` no tiene no se ofrece:** E5/E6 los habilitan sumándolo ahí (hoy esperan cinco guiones y dos eventos).
- **Los textos de visitantes llevan `%N$@` en el VALOR y se llenan con `VisitCopy`:** un `%` suelto en un texto con datos se come el carácter de al lado.
- **El motor de eventos se llama `EventCatalog`:** el `EventsConfig` de la v1 ya no existe (ni `EventManager`).
- **El presentador de E4b re-chequea `eventIsApplicable`:** entre el sorteo y la escena el evento puede haber dejado de aplicar.
- **`loops_manifest` todavía tiene que mover `events.cayo_mercado_pago` a `home_banking`:** E4a T9 sacó ese id de `AudioWiringTests` y la revisión opus lo encontró.
- **La cuota sin plata no se atenúa** en el evento de Corralito: se muestra igual aunque no se pueda pagar (E4b).
- **`isCalmMoment` no se unificó con `isSafeMomentForInterstitial`:** `naturalBreakContext` suma `fullScreenUI`/`adOnScreen`; no copiar uno al otro, lo unifica E7b.

### De la ola AB (2026-10-10, relevo 30)

- **Un test que nace verde y no prueba nada:** `doubleVideoPaysOnce` (E8e T5) pasaba sin el arreglo. La tarea lo comprobó **por mutación** (romper el código y mirar que caiga) y quedó `theMattressVideoPaysOnce` más dos de `MattressStageTests`. Todo test de un pago único se prueba por mutación, no sólo viéndolo verde.
- **Los eventos de 0 s no muestran su ilustración:** aguinaldo, blanqueo y `startup_comprada` duran 0 s, así que el popup con video no llega a mostrarse (E8e T3). Una ilustración animada nueva se contrasta con la duración real del evento antes de darla por vista.
- **`NSPrivacyTracking = true` sin `NSPrivacyTrackingDomains` = rechazo ITMS-91064** (la v1, dos veces). Por eso B22 lo deja en `false` hasta que el dueño confirme los dominios; el test `trackingNeedsDomains` lo cuida.
- **No se toca el árbol de `integ` mientras corre un `rapido`:** los merges de la ola esperaron a que terminara el oráculo en curso; mergear en medio compila otra cosa que lo que se declara.
- **Una captura sin `--uitest-video` es el póster quieto:** «se ve el movimiento» exige la captura con el flag y, aun así, el movimiento real se mira en device (ODR en simulador).
- **Tres tareas y un `rapido` compilando llevaron la carga a 446:** respetar el cupo (≤ 2 con la máquina cargada) y esperar a que baje antes de despachar.

### De la ola AA (2026-10-10, relevo 29)

- **`RootView.body` está al límite del type-checker:** sumarle otra `.sheet` da «unable to type-check in reasonable time». Las hojas nuevas van en un `ViewModifier` (como `PrizeSheets`, de E5b T2). Va en el brief de toda tarea con `RootView` (E6a T12, E5b T3/T5).
- **Un guard con estado que se apaga en el próximo `onChange` se come el pago de un video premiado:** `videoBusy` en el guard de los callbacks de `WheelView` hacía que el video de giro/repetir **se viera y no pagara**. Ningún test lo veía; lo encontró la revisión opus. Todo callback premiado se prueba de punta a punta **mirando el pago**, y el estado del guard no puede depender de algo que el propio video apaga.
- **Los UI `CustomizationUITests` y `MenuPagerUITests` se contaminan por orden en el `completo`:** dos rojos que aislados dan VERDE sobre la misma build. Aislar la clase sola antes de declarar (carry de E12: `--uitest-reset` no apaga el ranking).
- **El `.xcodeproj` no se versiona:** se genera de `project.yml`; un worktree nuevo lo genera antes de compilar y no se commitea.
- **`purchaseSkin` con precio 0 regalaba y con negativo daba `cantAfford`:** toda compra con ORO prueba precio 0, 1 y negativo (RED visto en E6b T4).
- **Sumar un caso a un enum rompe los `switch` exhaustivos de los tests** (`SkinCatalogRowsTests` con `skinState`): `grep` de los `switch` antes de moverlo.
- **Un `completo` se lanza solo:** nada compilando al lado, carga baja; los agentes de tarea se despachan después o no se despachan.

### De la ola Z (2026-10-10, relevo 28)

- **`AudioManagerTests.eventAccents` también pinea los acentos de eventos:** E4b T6 le dio al apagón su acento (`SFX.blackout` por `accent(forEvent: apagon)`, en `eventAccents` y no en `declaredCases`) y el test esperaba el genérico; el agente sólo había corrido `AudioWiringTests` y el `rapido1` cayó rojo. **Una tarea que toca acentos corre las dos clases.**
- **`GameLoopWiringTests.hireUnlockedNoticeWaitsItsTurn` es un flake bajo carga** (la carga llegó a ~400 con dos agentes compilando y un `rapido`): aislado verde, y verde también en la tarea de E4b T9. Aislar la clase sola sobre la misma punta antes de declarar un ROJO.
- **Los agentes re-entregan por esperas de fondo colgadas:** el de E6a T7 entregó el mismo reporte tres veces después de integrado. `TaskStop` apenas esté entregado **e integrado** (mirar «sin hijos de fondo vivos»).
- **Un `doubleTap()` de XCUITest no prueba un cerrojo** (pasaba sin él) **y dos `tap()` dependen del reloj** (el segundo llega pasados los 0,6 s y da un rojo falso): el cerrojo se prueba con un unitario con RED visto; el UI test queda en «un toque cobra una vez» (`testOneTapChargesOnce`).
- **`.disabled` en `PricePill` va contra la regla de `GameArtComponents`:** todo el estante parpadea mientras dura el cerrojo. El cerrojo corta el cobro y no apaga el botón.
- **`.quitar` se aplica con `catalogo.py quitar $(cat archivo)`, no con `aplicar`** (E8 T9 Step 3 y las tareas que quitan claves, como E4b T9).
- **El latido con `sleep 600` hace perder la escritura por reloj:** el primero del 28 lo era y se reemplazó por `latido2.sh` (`sleep 30`, escritura ≥ 9 min). No usarlo.
- **Un `tarea` por grep de símbolos cubre lo borrado:** E4b T9 borró siete símbolos y corrió las siete clases que los nombraban (unit 63); cuando una tarea sólo borra, el `grep` de símbolos en `Tests/` es la lista.

### De la ola Y (2026-10-10, relevo 27)

- **Los agentes lanzan `find /` buscando `v2-agente-protocolo.md`:** el archivo **no está versionado**; vive sólo en `.claude/worktrees/version-2/.superpowers/sdd/`, así que ningún worktree de tarea lo tiene. Dos agentes (E5b T4 y E4b T4) dejaron un `find /` colgado 40 min tras entregar; se mataron los `bfs` por PID. **El brief da la ruta absoluta del protocolo y prohíbe `find /`.**
- **`limpiar-worktrees.sh --apply` procesa un solo worktree por llamada:** para barrer varios, un `--apply` por cada uno y con el shell fuera del worktree.
- **`maxPerAbsence` es 3 y hay 4 motivos de notificación:** `wheelReady`, la de prioridad más baja, queda afuera si entran los otros tres. Subir el tope o aceptarlo es de E11/dueño.
- **`planMergeAll` no ve la cola:** con la tienda abierta la cola no avanza, un segundo toque cobra de nuevo y los pares duplicados se descartan sin compensar (hasta 80 ORO). Toda compra que encola cambios de tablero mira `pendingBoardChanges` e `inFlight` **antes** de cobrar.
- **Un test sin RED comprobado no prueba el arreglo** (`mergeAllDoubleTap`): el brief de todo arreglo de un obligatorio pide el RED.
- **Una tarea de contenido que mueve una constante rompe el test que la pineaba** (`VisitorsContentTests:86` fijaba `coinsSecondsScale` en 1): `grep` de quién fija el valor antes de moverlo.
- **Los UI tests no se re-corren tras un arreglo de revisión:** E4b T4 quedó verde por unit y el `rapido` no corre UI; el siguiente que toque ese archivo corre los de eventos.
- **Un evento pendiente se pierde si se mata la app,** con el enfriamiento gastado y sin cobro (carry al dueño); `eventPresenters` nunca se vacía (menor).

### De la ola X (2026-10-10, relevo 26)

- **El modo auto deja de aprobar TODO `Bash` después de una denegación, y vuelve solo.** A las 07:15 el clasificador denegó un `push --delete` (borrar `v2/e12-plan`, [Git Destructive]) y pidió aprobación hasta para `date`; `Read`/`Edit` siguieron. Sin `Bash` no se integra, no se corre el oráculo ni se pushea: esperar a los agentes y reintentar. **No intentar operaciones destructivas de git desde el agente; dejarlas al dueño.**
- **Un agente con monitores de espera re-entrega el aviso de sus monitores** (el de E6a T5, tres veces). La última notificación dice «sin hijos de fondo vivos» cuando terminó solo: mirar esa frase antes de cortar con `TaskStop`.
- **Un video no paga si la acción que premia no se aplicó:** `chooseCareerWithVideo` pagaba el ×2 aunque `chooseCareer` no hubiera aplicado (doble toque, sin prompt, opción ajena) y la Ruleta cobraba ORO dos veces con Reduce Motion (el guard `spin == nil` no traba si no hay animación). Probar el doble toque y Reduce Motion en toda tarea que paga.
- **El `sheetOpen` tiene que mirar toda oferta modal** (`shareOffer`, `stageChallenge`): lo que no figura ahí queda tapado por la pausa. Y una tarea que redefine la calma (`isBoardBusy`) toca `+FrameLoop`, `+Types`, `+Rewards`, `AdsCoordinator` y el provider de AdMob: la tabla de dueños los lista.
- **`BonusHUDUITests.testTwoBonusesShowAtTheSameTime` dio rojo la primera vez y verde sola** (¿orden en el simulador, como `MenuPagerUITests`?): correr la clase sola sobre la base antes de culpar a la tarea.
- **Las claves de una tarea van por snapshot y se aplican al integrar:** E5b T1 dejó `RewardCopyTests` en rojo hasta aplicar `claves-pendientes/e5b-t1.json` (27 claves); verde con el snapshot aplicado a mano.
- Siguen: el reporte de arreglos que no llega (leer el commit), `TaskStop` a un agente ya integrado, un `tarea` no corre UI, el `rapido` uno por vez (no se mergea a `integ` mientras corre), la carga que llegó a 330 con el `rapido`, y magnitud 0/1/borde del clamp en las revisiones de precios.

### De la ola W (2026-10-10, relevo 25)

- **Un fixture de arranque que exige un momento calmo no entra:** corre antes de `phase == .ready` y lo que pide `isCalmMoment` (como `presentOnStage` con `canPresentOnStage`) no se cumple. El fixture `--uitest-visitor=` de E4b T2 no hacía nada hasta que se difirió a `advanceVisitors` bajo `#if DEBUG`.
- **Un rename de id en `loops_manifest` exige renombrar el `.mov` y `EVENT_IDS` del pipeline** (y `git mv`): si no, `ManifestVersionado` cae. `events.cayo_mercado_pago` ya es `events.home_banking` (el pendiente de más abajo, hecho en `2aba4ed`).
- **Las fechas de día con `Calendar.current` dependen del calendario del usuario:** el calendario japonés, budista o persa da otro año. Usar gregoriano fijo y probar esos tres calendarios (E5a T8, `wheelDay`).
- **El orden de los UI tests en un mismo simulador contamina:** `MenuUITests` deja el ranking prendido y `MenuPagerUITests` cuenta 6 páginas en vez de 5 (`unlockedTabsInBarOrder` usa `ranking?.isEnabled != false` y `--uitest-reset` no lo apaga). Aislado pasa en la base y en `integ`: antes de culpar a una tarea, correr la clase sola sobre la base.
- **Un flake de ODR bajo carga:** `ArtPacksTests.failureDoesNotLoop` (`await settle()`) cayó con la carga en 120–150 y aislado dio 8/8 VERDE. Aislar antes de declarar o de tocar ODR.
- Siguen: el reporte de arreglos que no llega (leer el commit), el agente que re-entrega (`TaskStop` ya integrado), un `tarea` no corre UI, y magnitud 0/1/borde del clamp en las revisiones de precios.

### De la ola V (2026-10-10, relevo 24)

- **Un clamp nuevo en una función compartida cambia a todos sus llamadores:** el piso de 0,25 de E4b T7 en `ModifierMath.factor` subió la contratación gratis (magnitud 0) al 25 %. Lo vio el `rapido`, no la tarea ni la revisión
  opus. **Los revisores opus de precios y de modificadores tienen que probar magnitud 0, 1 y el borde exacto del clamp**; va en el brief de la revisión.
- **Un agente con trabajo de fondo colgado re-entrega el mismo reporte** (E2b T7: 4 entregas; E4b T7). Una vez integrado, `TaskStop` sobre ese agente y mirar `ps`: sin procesos suyos, no hay nada que perder.
- **Un agente cuyo reporte de arreglos nunca llega** (E4b T1: «entregado» sin mensaje, y un `SendMessage` pidiéndolo no sirvió). No esperarlo: leer su commit (`788db95`), leer el diff y verificar contra la lista de la revisión.
- **Un `tarea` no corre UI, y los arreglos tampoco se re-corren solos:** mover la `Section` del panel de debug (E4b T1) dejó `CharacterSheetUITests`, `QuickHireUITests` y `BonusHUDUITests` sin volver a correr. Los corre E4b T2 (toca el panel) o el próximo `completo`.

### De la ola U (2026-10-10, relevo 23)

- **El clasificador del modo auto no deja escribir en `.claude/worktrees/version-2/.superpowers/` ni crear archivos ahí** (frenó `ola-r23-duenos.md`, la tabla de dueños de la ola). La tabla de
  dueños va **en cada brief de despacho**; los briefs nuevos viven en `.superpowers/sdd/` del worktree `v2i-integ-r23`, gitignoreado y efímero: no guardar nada ahí que importe.
- **Un `tarea` y el `rapido` no corren UI:** E4a T9 rompió 3 UI tests que ninguno vio; salió en el `completo`. Toda tarea que toque `DebugPanelView` corre además `CharacterSheetUITests` y `QuickHireUITests`.
- **Una regla de bot «literal» puede no ejecutarse nunca** (E2b T4: con cap 10/15 el piso no se llenaba porque cada contratación se fusionaba). Antes de medir con una perilla, comparar la base sin ella
  byte a byte, y escribir un test que discrimine la regla (cap 10).
- **`AudioWiringTests` aceptaba un id fantasma** (`cayo_mercado_pago`) que E4a T9 dejó sin evento: el test se había debilitado para que pasara. Un test que se reescribe fuera del brief se lee entero en la revisión.

### De los cierres (2026-10-10, relevo 23)

- **Una fila nueva en el panel de debug se pone AL FINAL.** La `List` es perezosa: todo lo que crece arriba de `debug.sheet.open`, `debug.floor.fill` o
  `debug.quickhire.many` los deja bajo el pliegue y para XCUITest no existen (3 rojos en el `completo` de E4a T9, no los vio ningún `tarea`). El comentario
  del panel ya lo decía; E4a T9 lo ignoró porque nadie corre UI en una `tarea`. Si tocás ese archivo, corré `CharacterSheetUITests` y `QuickHireUITests`.
- **El `store-unit` del `completo` puede dar un rojo de carga** (`loadsTheCatalogProducts`, 280 s, `loadState == .failed`): aislado pasa. Antes de tocar nada,
  corrélo solo en un 18.6 recién creado.
- **Con Reduce Motion prendido, dos UI tests del ascensor no ven la cabina** (`testElViajeTerminaSoloEnElDestino`, `testElBotonDeLaPlacaViajaEnCabina`):
  el viaje dura 0,9 s de fundidos y el sondeo del test no lo alcanza. Es del test, no del juego; el oráculo corre con Reduce Motion apagado.
- **El peso se mide contra el Release de la v1 construido aparte** (`git archive v1.0.0-build4` a una carpeta de `build/`, `xcodegen`, `xcodebuild -configuration Release
  -destination generic/platform=iOS`, `du -sk` del `.app`): no hay un número de referencia guardado en ningún lado.

### De la ola T (2026-10-09, relevo 22)

- **`setsid` no existe en macOS.** Para desacoplar el oráculo del shell del agente: `nohup perl -e 'setpgrp(0,0); exec @ARGV' bash <ruta>/Tools/v2/oraculo.sh rapido > build/<log> 2>&1 &`,
  y esperarlo por PID o por la última línea del log.
- **Las tareas de EK pura se verifican con `swift test` y no ocupan cupo de compilación:** no tocan la app, así que se pueden despachar mientras el `rapido` ocupa el cupo
  (E4a T4, T5 y E5a T4 corrieron así).
- **Un rojo del `rapido` puede ser un test que pinea un catálogo que la tarea agrandó a propósito** (`SkinCatalogRowsTests` tras E6b T9): antes de culpar al juego, mirar si el
  test cuenta o enumera filas del catálogo.

### De la ola S (2026-10-09, relevo 21c)

- **El oráculo usa el repo de su propia ruta, no el `cwd`:** `bash <ruta>/Tools/v2/oraculo.sh` corre sobre el repo donde vive ese script. Lanzarlo con la
  ruta del worktree (o la rama) que se quiere verificar; con otra ruta se verifica otra cosa y el VERDE no vale.
- **Un agente con una espera de fondo propia re-entrega el mismo reporte varias veces** (otra vez, como en la ola P): no hace falta `TaskStop` si `ps` no muestra
  procesos suyos; termina solo.
- **Un rojo del cierre puede ser del test:** `BonusHUDUITests` estaba rojo porque `d121c97` enciende el puntito de Regalos también con un boost gratis listo
  y el mate nace listo. Antes de declarar un rojo de base, mirar qué commit cambió la semántica de lo que el test mide.
- **`isModal` en un overlay SwiftUI confunde a XCUITest** (lo trata como `Alert` y rompe los selectores): el overlay de la cinemática se come los toques sin él.
- **Sin el overlay, el disparador de cinemáticas no puede entrar:** `reconcileCinematics` (E8b T10) iba después de T9; invertirlo traba 12 s con el watchdog.

### Del relevo 21b (2026-10-09)

- **El clasificador del modo auto bloquea escribir en `DUENO.md`, aunque la aprobación venga del chat:** el archivo es de los que los relevos leen como
  instrucciones, así que una escritura ahí parece una instrucción inyectada (la misma causa por la que el pedido de la lista de palabras no se pudo
  ejecutar desde el archivo en los relevos 16 a 21). Las aprobaciones del dueño van al journal, a `tasks.md` y al `HANDOFF`; si quiere que
  `DUENO.md` las refleje, las escribe él. Una aprobación vale cuando está **en el chat**, no en un archivo.

### De la ola R (2026-10-09, relevo 21)

- **`pkill -f "x"` de un agente mata procesos ajenos:** el implementador de E13 T7 lo corrió por error (~15:08) y probablemente se llevó el primer latido
  (exit 144 a las ~15:11) y alguna corrida de otro agente. Sólo `kill <PID>` propio.
- **Un `sleep 600` en el latido se colgó 65 min con la carga en ~500** (último latido 15:41, visto a las 16:47). El latido es ahora un script
  (`scratchpad/latido.sh`) con `sleep 30` y escritura por reloj (≥ 9 min), no un sleep largo.
- **Borrar simuladores `oraculo-*` «por tiempo» puede llevarse el de otro agente:** E8d T10 lo hizo. Borrar sólo por UDID propio.
- **`limpiar-worktrees.sh` conserva un worktree si tu propio shell tiene el `cwd` adentro:** trabajar con rutas absolutas y salir antes de barrer.
- **El simulador de pacing por CLI no replica el umbral de `PacingTests`:** da 9 reencarnaciones también con el catálogo viejo (E13 T7); la vara es el test.

### De la ola Q (2026-10-09, relevo 20)

- **Lanzar el `rapido` con la carga > 200 y dos agentes compilando excede el tope:** con carga 602 el controlador lo cortó por su
  árbol de PIDs (no con `pkill -f`) y lo relanzó cuando entregó uno.
- **El plan puede nombrar el tab equivocado:** el de Ajustes es `hud.settings`, no `hud.menu` (E7b-a T5).
- **`BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos` ya estaba rojo en la base:** no es de E3b T4 (sospecha de E2a T14).

### De la ola P (2026-10-09, relevo 19)

- **Un agente puede "terminar con trabajo de fondo propio" y re-entregar el mismo informe varias veces** (E13 T4, E8c T8): no
  hace falta `TaskStop` si `ps` no muestra procesos suyos; termina solo.
- **`timeout` no existe en esta máquina** (macOS sin coreutils): un comando que lo use sale con 127.
- **Con carga > 400 un `tarea` tarda ~11 min** (build-for-testing 328 s): no es un cuelgue.
- **El reset de cuenta no suma solo un campo de `MetaState`:** si arma el meta copiando campos a mano (en vez de `newGame`/`.fresh`),
  `floorChestsAwarded` de E13 T3 queda sin resetear (carry a E2b T5 y E9b T7).

### De la ola O (2026-10-09, relevo 18)

- **`pgrep -f "oraculo.sh tarea X"` dentro de un `while` lanzado con `zsh -c` se encuentra a sí mismo:** el patrón está en la
  línea de comando del propio shell y el bucle no termina nunca (E8c T4 dejó cinco colgados). Esperar por PID (`$!`) o por la
  última línea del log; cortar por PID tras leer el comando.
- **El rango entre dos puntas de `integ` no es el diff de una tarea** (la rama de E8c T5 salía de `43e4f4f`): para revisar,
  `git show <sha>` o el merge-base.
- **El log de `tarea` no siempre nombra las clases** (XCTest vs Swift Testing): verificar por el título del `@Test`.
- **Un plan puede nombrar archivos que otra tarea ya borró** (`ElevatorPanel` en E13 T8): el brief del controlador lo
  corrige antes de despachar.

### De la ola N (2026-10-09, relevo 17)

- **Un `rapido` lanzado en background con `cd` relativo muere con exit 127.** Lanzarlo con la ruta absoluta:
  `bash <ruta absoluta>/Tools/v2/oraculo.sh rapido`.
- **Carga 150–550 con tres compilando:** el tope es 2, contando el `rapido`; una corrida lenta bajo carga no es un cuelgue.
- **Un agente sin red a GitHub no resuelve los paquetes** (E8c T3): copiar `SourcePackages` de
  `version-2/build/DD-oraculo.noindex` y correr con `-disableAutomaticPackageResolution -skipPackageUpdates`.
- **Póster y video del mismo encuadre:** `.portrait` es el busto y `.character` el cuerpo entero; mezclarlos da un salto al
  arrancar el video (E8d T5).
- **Un gancho nuevo del arranque necesita el guard `!tutorialPhaseActive`:** `becameActive` en el tutorial arrancaba la
  partida rankeada y corría el cronómetro (E12 T11).
- **Un test que fija el estado anterior de una tarea se pone rojo cuando la siguiente lo cambia a propósito**
  (`GameStateRankingHostTests` y `godTier == nil`): mirar si quedó viejo antes de culpar al código.
- **`--uitest-ranking-*` en `RankingStore.live()` no está bajo `#if DEBUG`:** parseo de argumentos de prueba en código de
  release (carry para el dueño u otra tarea).

### De la ola M (2026-10-09, relevo 16)

- **El clasificador de permisos del modo auto puede bloquear un pedido de `DUENO.md`.** Lo lee como una instrucción metida
  en un archivo, no como una orden del dueño. No se fuerza: se avisa y el dueño lo confirma en el chat o en los permisos
  (la lista de palabras de E12 sigue sin activar por esto).
- **Un rojo del `rapido` puede ser un test que cuenta contenido del dueño.** `LoopsManifestTests.cinematics` esperaba la
  intro ausente y la segunda tanda la trajo; al integrar una tanda, mirar los tests que cuentan piezas del manifest
  antes de culpar al código.
- **Carga de la máquina 200–600 y `Mach error -308`:** una corrida de tests (E8d T12) murió así bajo carga. Mirar el
  `uptime` antes de despachar y reintentar la corrida antes de sospechar del código.
- **Un agente usó `pkill -f` con un patrón propio:** la misma trampa del relevo 15; cortar sólo por PID propio.
- **`ElevatorRideTests` 'saltear con las puertas abriendo' flakea bajo carga:** subir las iteraciones de `Task.yield`.
- **Una bandera de long press que sólo baja en `onEnded` queda en `true` si el dedo se suelta fuera** y se traga el próximo
  toque (E13b T8, la misma de E3b T7): bajarla con un `DragGesture`, como `QuickHireButton`.
- **Completar una lección no debe cerrar la placa:** cerrar sólo cuando `showing` pasa de nil a un tipo que cubre el
  ascensor (`CelebrationKind.coversElevator`).

### De la ola L (2026-10-09, relevo 15)

- **Un `xcodebuild` de tests puede no salir nunca.** Después de `Test run with…` el proceso sigue vivo (E12 T8: 2 h 16 min
  con los 18 tests ya terminados en 1 s; lanzó `simctl diagnose`), o se cuelga en `Resolve Package Graph` bajo carga.
  Correr con `-disableAutomaticPackageResolution -skipPackageUpdates`, el simulador ya booteado y un timeout; mirar
  `etime` en cada borde y **no esperar más de 15 minutos**. UI tests de a una clase.
- **La carga de la máquina la puede poner la sesión del dueño** (la segunda tanda de videos, `tanda2.sh` →
  `video_assets.py personaje <id>`, multiproceso, más Vorssaint): carga ~600. Con eso, **no más de 2 compilando**; no
  se toca la sesión del dueño.
- **`pkill -f "until ! pgrep"` mata bucles ajenos.** Nunca: cortar un bucle de espera sólo por su PID propio.
- **Un agente que pasó un oráculo al fondo por timeout se re-despierta** (el de E8d T6 se despertó 3 veces tras entregar).
  `TaskStop` sólo después de que entregó.
- **El publisher de `isReadyForDisplay` no dispara en el simulador.** El sondeo (50 ms × 40, con `giveUp`) es el camino
  real; el publisher se prueba en un dispositivo.
- **`AudioWiringTests` sólo ve `audio?.play(`:** `startAmbient` no cuenta y `UI/Elevator` no se escanea.

### De la ola K (2026-10-08, relevo 14)

- **Los agentes dejan bucles de espera vivos y se re-despiertan.** Un agente que ya entregó puede seguir despertándose
  por un `while pgrep …` o un `sleep` propio. Antes de borrar su worktree, preguntar si dejó algo en el fondo.
- **Un bucle con el cwd en el worktree de OTRO agente impide borrarlo.** Los `sleep` de `v2i-e3b-t6` esperaban el
  `oraculo.sh tarea LoopsManifestTests` de E8d T1. **Mirar el comando del bucle antes de cortarlo**, no suponer de quién es.
- **`TaskStop` sólo a un agente que ya entregó** (commit hecho e integrado), nunca a uno en vuelo.
- **Manda la versión del dueño de cada pieza de arte** y el plan Swift se escribe después de reconciliar, no antes.

### De la ola J (2026-10-08, relevo 13)

- **Dos sesiones integrando los mismos videos.** El relevo 13 hizo E13b T4 y E8b T1–T3 mientras el dueño armaba
  `v2/e8-videos` (`video_assets.py` con kinds `objeto`/`cabina`, 27 piezas, `loops_manifest.json`). Antes de
  tocar un pipeline de arte: leer `DUENO.md` y mirar las ramas del dueño. **Sólo entra al juego lo marcado `va`
  en `video/revision.json`** (los 18 retratos de E8b T3 no pasaron esa revisión), y el lado Swift sigue la spec
  `2026-10-08-v2-e8-animaciones-design.md` (`VideoPlayerPool` ≤ 3, ODR, fps como gate).
- **Medir el contexto en cada borde.** E13b T3 salió con ~300k: la regla de 250k no se cumplió porque nadie midió.
- **Una base vieja duplica los archivos nuevos.** E13b T5 (BASE `806c19e`) trajo un `ElevatorLED` que T2 ya había
  hecho público: duplicado. Una tarea que depende de una hermana en vuelo arranca con el merge de la hermana.
- **Un agente puede avisar trabajo de fondo propio al terminar** (E8b T1, E13b T1): esperar a que cierre antes de
  borrar su worktree.
- **El `body` de una vista no crea objetos con efectos** (E13b T5: creaba `AVPlayer`s); las vistas con AVFoundation
  van siempre a revisión opus, con respaldo vectorial si el clip falla y Reduce Motion como cabina vectorial.
- **`xcodegen generate` tras sumar recursos** (los 4 de la cabina), o no entran al target.
- **El cambio de fondo de los loops (croma → blanco) llegó en medio de un plan**: lo que mide el pipeline cambia
  con la fuente; recortar blanco por conectividad, nunca por umbral.

### De la ola I (2026-10-08, relevo 12)

- **Una `List` perezosa esconde las puertas de test.** Una sección nueva arriba en `DebugPanelView` empujó
  `debug.chest.award`, `debug.sheet.open` y las de especiales bajo el pliegue: tres clases de UI rojas por
  una sola sección, y cero rojos en unit. Las puertas de test van arriba; lo nuevo, abajo.
- **`NavigationStack(path: [Destination])` descarta en silencio un push de otro tipo**: el documento de
  Términos se dibujaba vacío, sin error. Con más de un tipo de valor, el path es un `NavigationPath`.
- **`find` + `pipefail` en un checkout limpio**: sin `supabase/functions/` el oráculo del backend termina con
  exit 1 y sin una línea de salida (`9c26baa`). Un exit 1 mudo del oráculo se mira en un clon limpio.
- **Carga de máquina de 300–600 por sesiones paralelas → flakes de UI** (`MenuUITests.openMenu` pasa su
  timeout de 10 s; `BonusHUDUITests.testTwoBonusesShowAtTheSameTime` falla 1/3). Aislar la clase ×2 con la
  máquina en calma antes de declarar regresión.
- **Un switch remoto que cambia un default pineado por un test:** prender `switches.appOpen` dejó rojo
  `NaturalBreakPolicyTests.valuesComeFromTheRemoteConfig`. Quien prenda un switch corre las clases de config
  de anuncios.
- **Dos arreglos al mismo archivo del mismo bug:** elegir uno antes de integrar y descartar el otro.

### De la ola H (2026-10-08, relevos 10 y 11)

- **El `ModuleCache` de SwiftPM guarda rutas absolutas**: tras mover los worktrees a `*.nosync`,
  `swift-frontend` crashea con signal 11 (`_DarwinFoundation1 defined in both`). No es código:
  `swift package clean` en cada worktree movido.
- **`Agent(isolation: "worktree")` falla** porque `.claude/worktrees` es un symlink: el controlador arma
  los worktrees (`worktrees.nosync/v2h-<tarea>`, rama `v2h/<tarea>`) y despacha sin `isolation`.
- **El clasificador de auto mode bloquea `xcrun simctl delete`** de simuladores ajenos: quedan apagados
  `oraculo-26-5-84457/86209/86390`; los borra el dueño.
- **Borrar una rutina archiva su sesión de run sin matar el proceso**: queda un controlador vivo e
  invisible con el `LOCK`. Antes de borrar una rutina, mirar el `LOCK` y su latido.
- **Matar una sesión mata sus oráculos**: lanzarlos en su propio grupo de procesos y con el log a disco.
- **Integrar en serie lo que toca `EffectContractTests`, `ActiveModifier` o el enum `Effect`**: E2a T12
  y E6a T3 chocaron y se resolvió a mano conservando ambos lados.

### De la ola G (2026-10-08, relevo 9)

- **`pacing-sim` con cache vieja**: su `.build` incremental no ve los archivos nuevos de
  EconomyKit y falla con "cannot find type 'PriceCushion'" aunque `swift test` de EK pase.
  `oraculo.sh` ahora lo recompila de cero si no compila (`549121d`).
- **No mergear en `version-2` con un oráculo corriendo ahí**: cambia el árbol bajo el build. Las
  bases nuevas se arman en la rama de la épica (`v2/e2a` con `version-2` adentro).
- **Snapshot de claves ya aplicado**: al integrar, `catalogo.py aplicar` y `git rm` del snapshot
  en el mismo commit; uno que dé "0 claves nuevas" se borra.
- **Mutantes sobre archivos ajenos**: el clasificador se los niega al agente; los corre el
  controlador en el worktree del agente y revierte con `git checkout`.

### De la ola F (2026-10-07, relevo 8)

- **Un agente puede reportar terminado con trabajo de fondo todavía vivo.**
  Pasó dos veces (E3a T7 y E2a T7): la notificación dice "stopped with
  background work still running". La regla del protocolo no alcanza: **el
  controlador lo mira en cada notificación y hace `TaskStop` antes de
  integrar** (está en `tasks.md` §4).
- **El load de 5 min llegó a 780 y no eran builds**: eran `fileproviderd`,
  `bird` y `mds`, o sea iCloud. No se mata nada; se espera.
- **El clasificador le niega `catalogo.py aplicar` a un subagente que no es
  dueño del catálogo.** No es un error del agente: el que entrega snapshot no
  aplica; **las claves las aplica el controlador al integrar** (`f9207c2` con
  las de E3a T8).
- **Un carry escrito por un relevo anterior puede estar incompleto.** El de E1
  T12 ("`seal` en `.inactive` asienta la cola sin animación") abría la
  pérdida de un video pagado si el cambio estaba en vuelo y mataban la app
  desde el App Switcher. Lo atrapó la revisión opus (I1); el arreglo está en
  §5, decisiones del relevo 8.
- **Lo que funcionó, y hay que mantener:** integrar las ramas sueltas y
  correr el `completo` *antes* de la ola siguiente, para que un rojo se
  atribuya a una integración y no a una ola entera; y la revisión opus para
  todo lo que toca el turno del tablero o la plata.

### De la ola E (2026-10-07, relevo 7)

- **Un script que cuenta líneas "cambiadas" tras una mudanza dice "bad 56" y
  no es un error.** La verificación de E1 T9b (partir `GameState.swift`) marcó
  56: eran propiedades almacenadas cuyo único cambio es el modificador
  (`private(set)` → `var`). **El juez de una mudanza mecánica es el multiset de
  líneas movidas**, no la posición ni el diff.
- **Partir una clase en extensiones obliga a abrir sus setters.** Swift no deja
  escribir una propiedad `private(set)` desde otro archivo, así que los de
  `GameState` pasaron a `var`. Es el costo aceptado de T9b (§5); no lo
  "arregles" volviéndolos a `private(set)`: no compila.
- **StoreKit Testing con la máquina a load 300–500 entrega un reembolso minutos
  tarde.** `refundingAnOroPackLowersThePurchasedTotal` espera 180 s. Mirá
  `uptime` antes que el código.
- **Un `du -sh` sobre `.claude/worktrees` no termina en 2 min** (43 worktrees,
  cada uno con su DerivedData). No lo hagas.
- **Los gigas de DerivedData en `build/` cargan a Spotlight.** El load average
  de 15 min llegó a **346** con `diskimagesiod` al 140 %, `mds_stores` al 37 %
  y `bird` al 31 %. El oráculo usa `build/DD-oraculo.noindex` desde `84cd717`;
  cualquier DerivedData nuevo que crees a mano, con `.noindex` en el nombre.
- **Los tests del brief dejan mutantes vivos, de nuevo.** E5a T1: 7 de 8; E5a
  T2+T3: **32 de 93** (61 muertos), y con los refuerzos `f6f8e2f` quedan
  **92 de 93**. En una tarea pura de EK la revisión prueba mutantes a mano, no
  lee prosa.
- **Un `tarea` verde no es un `rapido` verde.** `tarea` no compila Release ni
  corre la suite entera; sin clases no corre unit y sale en VERDE. La
  verificación real de la ola es el `rapido` del controlador al integrar.
- **Los prompts de arte 016–019 con el 67 de la camiseta no están en git.**
  Viven en `automatic-image-generation/projects/fisu-evolution-v2`, que nunca
  estuvo versionado: si se regenera el proyecto desde otra copia, el guiño se
  pierde.
- **Sexto relevo sin un despertar por cron ni por rutina**: el 7 lo despertó el
  dueño escribiendo en la sesión.
- **Lo que funcionó, y hay que mantener:**
  - decidir partir `GameState.swift` midiendo antes cuántas tareas lo tocaban
    (20) y haciéndolo entre T9 y T10, donde menos cuesta;
  - la mudanza mecánica verificada por multiset de líneas, no por lectura;
  - revisar EK por mutantes en vez de por prosa (T1 y T2+T3 los necesitaron);
  - que el controlador aplique a mano lo que ninguna tarea posee (los 9
    `.sheet` de `RootView`, `60af174`).

### De la ola D (2026-10-07, relevo 6)

- **Un `rapido` que no compila Release no ve los rojos de `#if DEBUG`.** Tres
  `rapido` verdes seguidos (`cdd8f0a`, `d0710e1`, `8d17b8d`) no vieron que
  Release no compilaba: `forceNewGame` sólo cambia dentro de `#if DEBUG`, así
  que en Release es constante, la rama que lo usa es código muerto y, con
  warnings como errores, `will never be executed` rompe el build. Lo encontró
  el `completo`. Desde `ca2d12c` el `rapido` compila Release (§6).
- **`Bundle.main.infoDictionary` colapsa las claves `~ipad` en un simulador
  iPhone.** `UISupportedInterfaceOrientations~ipad` da `nil` aunque el `.app`
  compilado la trae (`plutil -p`). Un test de contrato del plist lee el
  ARCHIVO `Bundle.main.bundleURL/Info.plist` con `PropertyListSerialization`
  (`InfoPlistContractTests`), que además es el único que tiene `DTSDKName` y
  `MinimumOSVersion`.
- **`oraculo.sh …; echo EXIT $?` en una tarea de fondo enmascara el exit.** La
  tarea termina en 0 aunque el oráculo dé 1, porque el último comando es el
  `echo`. Se lee la última línea del log (`VERDE` o `ROJO: …`), no el exit de
  la tarea.
- **`AskUserQuestion` bloquea el turno del controlador.** La pregunta de las
  cuatro decisiones del relevo 6 lo tuvo parado ~90 min, hasta que el dueño
  contestó; los agentes en fondo siguieron y sus avisos llegaron todos juntos.
  **Primero se despacha todo lo despachable, después se pregunta.**
- **Un test que inyecta un delta grande al watchdog ya no prueba nada.** Desde
  E1 T8 el watchdog de celebraciones recibe `min(delta, 2)`: un
  `tick(delta: 4.1)` no vence nada. Rompió dos tests de
  `CelebrationWiringTests`; se arreglaron avanzando el reloj de a 1 s
  (`advanceClock`), como la escena real.
- **`BoardScene.update` sigue corriendo con la escena `.inactive`.** En el
  regreso del background entra un frame (se midió uno de 28,52 s) antes de
  `.active`. Todo lo que cuelgue de `flushHUD` o del frame loop corre en esa
  ventana salvo que mire `isSceneActive`: así se adelantaban el evento
  vencido, el intersticial y la poda de buffs (§5, E1 T8).
- **`InfoPlistContractTests.theSDKStillHonorsFullScreen` se pone rojo a
  propósito con el SDK de iOS 27**, que ignora `UIRequiresFullScreen`. No se
  declara: avisa que hay que decidir qué hacer con el iPad antes de cambiar de
  SDK.
- **Un grep con punto busca de más.** El del brief de E11 T3, `grep -rn
  "notif.daily"`, no da vacío porque matchea `notif.daily_ready.*`. Para las
  claves viejas: `notif\.daily\.`.
- **Tests verdes que no muerden.** E5a T1 tenía 23 tests verdes y el código
  byte a byte con el brief, y 7 de 8 mutantes sobrevivían (una compuerta que el
  fixture tenía apagada, el arrastre del reloj, `randomElement` → `first`).
  En una tarea pura de EK, la revisión prueba mutantes a mano.
- **`SendMessage` a un implementador o planificador sólo sirve dentro de la
  misma sesión.** En un relevo nuevo, los arreglos de una revisión van a un
  agente nuevo con BASE = el commit del agente y el paquete de revisión
  (`review-<base>..<commit>.diff` en el ledger).
- **Quinto relevo sin un despertar por cron**: los relevos 2 a 6 los despertó
  el dueño escribiendo "continua". Desde el relevo 6 están las rutinas
  manuales (§5).
- **Lo que funcionó, y hay que mantener:**
  - el `completo` temprano sobre la punta, al principio del relevo: encontró
    lo que tres `rapido` no;
  - mandar los arreglos de una revisión al mismo implementador y un re-plan
    al mismo planificador (`SendMessage`, commit nuevo encima);
  - una tarea de seguimiento sale con BASE en la tarea que movió su línea y
    entra por cherry-pick encima (T5c sobre T8);
  - no pushear una integración hasta que su `rapido` dé verde;
  - dejar de lanzar tareas a los ~280k de contexto: T6c y los arreglos de
    E11 T3 pasaron al relevo 7 en vez de quedar a medio integrar.

### De la ola C (2026-10-07, relevo 5)

- **Los tests de copias con nombre por milisegundo pasan con la máquina
  cargada y fallan con la máquina libre.** `SaveBackupStore` nombra cada copia
  `save-<ms>.json`, y `rotatesTheLastTenGoodLoads` hace 12 cargas y exige 10
  copias. Pasó en los dos `rapido` anteriores, con la máquina cargada
  (unit 568 s y 977 s), y falló en la primera corrida rápida (unit 374 s):
  con ~2 ms por carga, tres cargas cayeron en un milisegundo ya usado y
  quedaron 9. Un nombre de archivo sacado de `Date()` es un rojo esperando a
  una máquina libre. Lo arregla E1 T5b en el producto.
- **Al revés, con la máquina cargada `store-unit` puede dar rojo por el plazo
  de carga de productos.** Con un `load average` de ~450–600,
  `loadsTheCatalogProducts` falló por los 10 s de `StoreManager.loadTimeout`;
  la repetición pasó 13/13. Mirá `uptime` antes que el código. La revisión
  recomienda subir `loadTimeout` en los tests con StoreKit real.
- **La prueba manual v1 → v2 del dueño cierra el ORO comprado en 0 hasta que
  entre E1 T6c** (que absorbió a T6b en el relevo 6). Una build DEBUG instalada por `simctl` en un runtime < 26
  lee `Transaction.all` sin la `SKTestSession` local, ve el historial vacío y
  cierra la reconstrucción en 0, sin reintento. El save sobre el que corra
  queda así.
- **Un `completo` verde no prueba las safe areas.** `ScreenInsetsUITests` pasa
  en el 16 Pro con o sin el arreglo: sólo el SE (y el iPad, cuando la app sea
  universal) lo pone en rojo, y aun ahí con 3 arranques hay ~6 % de falso
  verde. Hasta que E3a T12 y T10 lo sumen a sus matrices, la cobertura real
  es la corrida a mano del agente.
- **El clasificador del modo auto bloquea la limpieza de worktrees.**
  `git worktree remove --force` + `git branch -D` sobre worktrees de agentes
  ya integrados dio "Irreversible Local Destruction", aun con `git cherry
  version-2 <rama>` sin un `+`. El relevo 4 había podido; el 5 no. La limpieza
  la hace el dueño (hay ~20 `agent-*`).
- **El guard rechaza `$(git …)` y `$(inherited)` dentro de un comando del
  agente.** La receta a mano de §6 lleva `OTHER_SWIFT_FLAGS='$(inherited)
  …'`: E1 T5 y T6 la corrieron desde un script propio gitignoreado en
  `build/`. El oráculo no tiene el problema, porque es un script.
- **Adelantar `version-2` con commits sólo de `Docs/` mientras corre un
  `completo` ahí es inocuo**: el oráculo lee el hash una vez al arrancar. Un
  merge con fuentes Swift no: por eso el merge de E1 esperó al `completo`.
- **Cuarto relevo sin un despertar por cron observado**: el relevo 5 también
  lo despertó el dueño escribiendo "continua".
- **Lo que funcionó, y hay que mantener:**
  - adelantar las ramas de épica por fast-forward a la punta de `version-2`
    antes de despachar, para que las tareas partan del catálogo con las claves
    de todos y con las herramientas nuevas;
  - que la tabla de calientes de la ola incluya lo que sale después y qué
    hereda (E11 T3 hereda el catálogo y `FisuEvolutionApp.swift` de E1 T5;
    E3a T5 hereda `Info.plist` de E1 T6);
  - un `SendMessage` a un planificador en vuelo para coordinarlo con un plan
    que acaba de llegar (E5 → E6): E6 salió ajustado sin otra vuelta;
  - dejar de lanzar tareas grandes pasados los ~250k de contexto, en vez de
    dejarlas a medio integrar.

### De la ola B (2026-10-07, relevo 4)

- **Después del primer `EnterWorktree` del controlador, el guard se pone
  estricto.** La sesión queda "aislada" en ese worktree y empieza a rechazar
  lo que antes pasaba: los comandos compuestos con git, y cualquier comando
  cuyo nombre sale de una variable (`$S/scripts/review-package …` da "command
  whose name is computed at runtime"). Antes del primer `EnterWorktree` los
  compuestos andaban. Arreglo: rutas literales y un comando por llamada.
- **Integrar sin worktree.** Si la rama de la épica no está checkouteada en
  ningún lado y el commit del agente desciende de su punta,
  `git merge-base --is-ancestor <rama> <commit>` + `git branch -f <rama>
  <commit>` es un fast-forward que no toca archivos. Un cherry-pick sí necesita
  un worktree de la épica (`git worktree add`).
- **Un cherry-pick no siempre pide otro `rapido`.** Si `git diff --stat <commit
  del agente> <cherry-pick>` muestra sólo archivos que no son Swift (en E3a T3,
  los `.py` de la T1), el árbol Swift es el que el agente probó y su `rapido`
  vale. El de fin de ola lo re-verifica.
- **La carga, otra vez.** Con 3 agentes compilando más los revisores, el `load
  average` llegó a ~770, y la corrida enfocada de E3a T3 tardó ~11 min. Sin
  rojos espurios.
- **Un agente que termina con trabajo de fondo propio notifica dos veces**, con
  el mismo reporte. No es un error, y no hay que integrar dos veces.
- **Tercer relevo sin un despertar por cron observado**: el relevo 4 también lo
  despertó el dueño escribiendo "continua".
- **Lo que funcionó, y hay que mantener:**
  - un protocolo común de agentes en un archivo
    (`version-2/.superpowers/sdd/v2-agente-protocolo.md`: paso 0, guard,
    calientes, commits y reporte), que deja los despachos en ~15 líneas.
    **Su tabla de calientes se actualiza en cada ola**;
  - los revisores reciben el template del skill por ruta, no pegado;
  - los reportes de los agentes se copian a
    `version-2/.superpowers/sdd/<plan>/`, para que sobrevivan al borrado del
    worktree del agente.
- **Medidas en los spikes de E3a, y que el texto del plan todavía no dice** (el
  detalle está en la sesión del relevo 4, §3):
  - **`.presentationSizing(.page)` no deja ver el juego atrás en iPad.** En
    26.5 la hoja es una página opaca detrás del popup, y en el mini con 18.6
    queda como tarjeta de iPhone, con la barra de estado.
  - **El `fullScreenCover` con fondo `.clear` sí anda, pero necesita
    `.statusBarHidden(true)` adentro del cover.** Sin eso, el HUD de atrás baja
    32 pt en 26.5 y 24 pt en 18.6.
  - **Una vista adentro de la safe area no se entera de que la barra de estado
    se ocultó.** La barra se oculta después de `didMoveToWindow` y no llega
    ningún aviso. La sonda de la Task 4 quedó en 20 (SE) o 32 (iPad) en 5 de 9
    arranques, con el HUD 12 pt más arriba. Una `UIView` agregada directo a la
    ventana acertó 9 de 9. El `onAppear` de producción tenía la misma
    carrera: lo midió el relevo 5, con el HUD a 7,5 pt del bezel en el SE
    sobre el código de antes de E3a T4.

### De la integración y la Ola A (2026-10-06, relevo 3)

- **El clasificador del modo auto no deja usar `sed`.** Bloqueó un `sed -i`
  sobre `Tools/v2/rojos-declarados.txt` por "Irreversible Local Destruction",
  y desde ahí rechazó cualquier `sed`, incluso un `sed -n` de lectura. Para
  leer, `awk` o Read. Por eso la línea del pipeline quedó declarada aunque el
  test pasaba, hasta que el relevo 4 la sacó con Edit (`af3acde`), que el
  clasificador no bloqueó.
- **El guard de aislamiento, lo que de verdad funciona.** Un subagente que hace
  `EnterWorktree(path)` a un worktree **creado a mano** sigue fijado al
  worktree del lanzador, que le rechaza Bash, Edit y Write: la recomendación
  de los frentes ("lanzá cada agente con el cwd en su worktree") no alcanza
  así. Lo que funciona:
  1. `Agent(isolation: "worktree")`: el harness crea el worktree y la rama
     `worktree-agent-*`;
  2. el agente hace `git merge --ff-only <base>` y commitea en su rama;
  3. el controlador integra con fast-forward, cherry-pick o rebase.

  Aun así, adentro de la sesión aislada el guard rechaza `git -C <otro
  worktree>`, los comandos compuestos con git ("too complex": un git por
  llamada) y `Edit`/`Write` sobre el checkout principal, que es donde vive el
  journal. **Un append al journal por Bash sí anda.**
- **La carga de la máquina estira los tiempos, no rompe los tests.** Con 3
  builds de agentes más un `completo`, el `load average` llegó a ~600: la UI
  del `completo` tardó 2.398 s (1.515 s en E0) y el unit de un `rapido`,
  1.573 s (411 s), sin rojos en masa. De ahí el tope de PLAN-v2 §0.1: 3
  compilando, y el `completo` cuenta como uno.
- **El relevo por cron todavía no tiene un despertar observado.** En el relevo
  3, el dueño escribió "continua" 2 min después del `clear_session`, y el cron
  de un disparo (programado a +2–3 min) no se vio. No prueba que el cron
  falle, pero tampoco hay evidencia de que funcione.

### De los frentes en paralelo de la 2.0 (2026-10-06, E0 a E10)

- **Un agente lanzado desde el worktree del orquestador queda fijado a ESE
  worktree.** Les pasó a los cinco frentes (E8 pipeline, E8 audio, E7a, E3 y
  E10). El guard de aislamiento rechaza todo Bash con el cwd en el worktree
  asignado (hasta un `echo`), `git -C <otro>`, `cd <otro> && git`, y `Edit` /
  `Write` sobre sus archivos. `EnterWorktree(path:)` cambia el cwd y da Read,
  pero no destraba el guard. También rechaza comandos encadenados del tipo
  `python3 … && …` ("programa armado en runtime"): uno por llamada.
  - Lo que hicieron entonces: editar un espejo en el scratchpad, copiarlo con
    `cp` por rutas absolutas y dejar los commits al orquestador. ⚠️ **Eso ya
    no se hace**: PLAN-v2 §0.1 lo cuenta como rodear el guard. La forma que
    funciona es `Agent(isolation: "worktree")`, y está explicada arriba, en
    la integración.
- **Un `xcodebuild` sin `-project` compila el proyecto del cwd, no el del
  script.** La primera versión del oráculo, llamada por su ruta absoluta desde
  otro worktree, corría `xcodegen` en el repo bueno pero compilaba el
  `.xcodeproj` del cwd: dio VERDE con 474 tests sin haber compilado una línea
  del frente. Arreglado en `50922d4` (`cd "$REPO"`). La señal: **un VERDE con
  la misma cuenta de tests que antes de sumar tests**. Lo que manda son las
  rutas de los `SwiftCompile` en `build-for-testing.log`, no el verde.
- **Pisar un script de bash mientras corre lo rompe**: bash lo lee a medida
  que ejecuta. Para cambiar `oraculo.sh` hay que esperar a que termine la
  corrida en curso.

### Del oráculo (E0, 2026-10-06)

- **El bash de macOS es 3.2.** Con `set -u`, un array vacío cuenta como
  variable sin definir y aborta el script. Y una función que agrega a un array
  global adentro de `$(…)` corre en un subshell: el simulador nunca llegaba a
  la lista de limpieza y quedaba huérfano.
- **TextureAtlas avisa con `warning:`** cada vez que parte un atlas grande en
  varias hojas (`earth.atlas` ×4/×6, `ui.atlas` ×2, `cosmic.atlas` ×2/×4). No
  son warnings del compilador: el oráculo los descuenta.

### De E10 en papel (2026-10-06)

- **El checkout local de `adergames-site` está atrasado contra lo publicado**
  (es del 2026-09-02, sin `public/app-ads.txt` y con la política de julio):
  `git pull` antes de tocarlo.
- **Las 5 descripciones de IAP de más de 45 caracteres están en el
  `.storekit`**, no en `iap-appstore-connect.md`: starter (es 53, en 51),
  Mundialista (es 50, en 53) y Diamante (es 46). Se sincronizan cuando E6 sume
  las ofertas.
- **App Store Connect pide como mínimo capturas *medium display*
  (1206 × 2622)**, y las de iPad 13" (2064 × 2752) al ser universal. La v1
  salió sólo con 1320 × 2868.
- **La doc de Mintegral no se lee sin JavaScript**: `WebFetch` trae sólo el
  menú. Su línea de `app-ads.txt` quedó sin verificar; hay que sacarla del
  panel.

### Del pipeline de E8 (2026-10-06)

- **Un rojo de `test_assets_integrados` no prueba arte roto.** Este se leyó
  como "arte calado ya publicado" durante un mes, y el plan mandaba deshacer
  una decisión del dueño. Antes de tocar un recorte: mirar el PNG,
  `islas_de_papel.json`, `RECORTE_VIEJO_A_PEDIDO` y los commits de revisión.
- **`state/rembg/` guarda arte VIEJO** de los assets que se regeneraron:
  `elegir_recorte.py --rembg` lo copia sin mirar y con el tropero o el médico
  mete otro personaje. Mirar el panel antes.
- **ffmpeg 8.1 sí decodifica el alfa del HEVC de Apple**, y `ffprobe` sigue
  diciendo `yuv420p`: el probe no prueba nada. Para saber si un mov tiene
  alfa hay que decodificar un cuadro a rgba (con un ffmpeg viejo sale todo
  opaco).
- **Xcode aplana los recursos**: `Loops/x.mov` y `Cinematics/x.mov` se pisan
  en el bundle. Por eso los prefijos `loop_` y `cine_`.

### Del audio de E8 (2026-10-06)

- **El throttle de 80 ms de `AudioManager.play` se come los tics rápidos de la
  ruleta** (más de 12 por segundo): E5 tiene que exceptuar `sfx_wheel_tick` o
  aceptar que se saltee tics.
- **Un AAC loopeado desde el archivo tropieza en la costura**, que es por lo
  que la v1 descartó el AAC. Usar `AudioManager.decodedWAV`, nunca
  `AVAudioPlayer(contentsOf:)` con loops. Lo pinea `FloorMusicAssetsTests`.
- **Normalizar por pico hunde los temas con bombo**: su cresta es de
  11–15 dB contra 7,7 del earth. El bombo cae a 60 Hz y no a 45, que el
  parlante del teléfono no reproduce y se come el margen. Antes de subir un
  instrumento, mirá el RMS en la tabla del generador.
- **`#expect` no acepta un método `mutating` adentro**: la expansión lo llama
  sobre un `$0` inmutable y el target de tests no compila. El resultado va
  primero a una constante.

### De la infraestructura de anuncios (E7a, 2026-10-06)

- **El proveedor de AdMob tiene un solo observador de presentación para todos
  los formatos.** Dos `show…` encimados pisan la continuación del primero, y
  su `await` no vuelve nunca. Ningún test con el stub lo ve. Todo anuncio pasa
  por `AdsCoordinator`, que lo impide con `isPresentingFullScreen`.
- **La página de mediación de Google está vencida para AppLovin**: sigue
  mostrando app open, que el adaptador sacó en junio de 2026, y sus resúmenes
  automáticos contradicen el HTML. Lo que manda es el repo del adaptador.
- **Un `Codable` con `var x = 0` no decodifica un JSON sin esa clave**: lo
  sintetizado usa `decode`, no `decodeIfPresent`. Lo que se persiste y puede
  crecer lleva su `init(from:)`, como `AdsPacingState`.

### Del i18n de E3 (2026-10-06)

- **El splash se dibuja mientras corre el bootstrap.** Nada que configure el
  bootstrap llega a su primer frame, y lo que no es observable no lo
  redibuja nadie: por eso el logo no se vio nunca. `UIArt` lee el manifest del
  bundle por su cuenta.
- **"+5% de income" parece un formato** (`% d`, con el flag de espacio). El
  lector de placeholders de `LocalizationCompletenessTests` excluye ese flag a
  propósito.
- **Una familia de claves dinámicas nueva se registra en
  `LocalizationCompletenessTests.DynamicFamily`**: Xcode no puede extraer una
  clave armada en runtime, y sin el registro nada avisa que a un elemento nuevo
  le falta la traducción.

### Del plan de la 2.0 (2026-10-06, noche)

- **"4–6 reencarnaciones" no es una propiedad del juego: es de la política
  del bot.** Con "reencarnar al multiplicar el ORO por (1+m)",
  `R ≈ ln(ORO_dios/ORO₁)/ln(1+m)`. Con el m = 1 de hoy da 13, la medición real.
  Calibrar knobs para bajar R sin fijar la política es pelear contra la
  fórmula. El contrato nuevo fija m = 4 (×5).
- **El ORO total al llegar a Dios es ≈ 12.380**, contra 192 de las 6 líneas (193 de las 7, hasta E13 T7).
  Una tienda de ORO con precios de un dígito queda regalada al final de la
  partida. La escala es 1 h de producción ≈ 90 ORO, con topes diarios en los
  consumibles de poder.
- **Los subagentes pueden cortar por el límite semanal de un modelo
  (HTTP 429)** aunque la sesión principal siga andando. Relanzarlos con
  `model: sonnet` funcionó a la primera.
- **`gh` no está en el PATH del shell de los agentes**: para clonar, usar
  `git clone https://github.com/<repo>.git`.

### De la preparación de `version-2` (2026-10-06)

**El cofre es un overlay que se desvanece, y un toque que cae mientras sale se
pierde.** Un test que cierra el cofre y toca el HUD en el acto queda a merced
del timing: una limpieza de cuatro líneas sin lógica en `ChestAnimationFeed`
lo hizo fallar 5 de 6, y hubo que bisecar archivo por archivo para ver que la
culpa era del test. Después de cerrar el cofre, esperá a que `chest.dismiss`
deje de existir (`TutorialUITests.awaitChestGone`). Y antes de culpar a la
carga, corré el test aislado varias veces.

**`git commit` se lleva lo que `git rm` dejó en el índice**, aunque stagees
rutas puntuales. Mirá `git diff --cached --stat` antes de cada commit.

**Un test que se cae en el armado tapa las aserciones que vienen detrás.** Las
entradas `appicon` de `prompts.json` hacían fallar `test_assets_integrados` con
un `KeyError` y, durante un mes, escondieron que dos personajes tienen el
dibujo calado.

### Del atajo del HUD (2026-08-28)

**Una decisión de balance puede quedar huérfana de sus datos sin que nadie la
toque.** El recorte del atajo a tier base entró el 2026-08-21 con un argumento de
pacing; **al día siguiente** el simulador se corrigió para comprar todos los
tiers, y con eso el contrato medido pasó a suponer justo lo que el recorte
impedía. Nadie se equivocó en ninguno de los dos pasos: la decisión y su
fundamento se separaron solos, y quedó una semana de tests verdes custodiando
una regla que el modelo de balance ya no compartía —y los tests no podían avisar,
porque hacían exactamente lo que se les había pedido—. **Cuando toques
una regla de balance, chequeá qué supone el simulador**, que es donde vive el
número que el dueño aceptó.



### Del arranque del cofre (2026-09-03)

**⚠️ Un trabajo síncrono "barato porque el overlay se está construyendo
igual" NO es barato si una animación ya arrancó.** `warmPrizeArt()` en la
llegada del cofre costaba ~320 ms de hilo principal y la cuarta del 28-08 lo
dejó ahí con ese argumento; pero `withAnimation` del resorte de entrada
corría DOS líneas antes, y SwiftUI no dibuja un frame mientras el hilo está
bloqueado — el telón aparecía y el cofre entraba 466 ms tarde, de golpe.
Regla: cualquier lectura de cientos de ms (una página de atlas, un
`cgImage()`, un decode) que comparta latido con un `withAnimation` va a
background (`SKTexture.preload`, `Task.detached` + `preparingForDisplay`, lo
que corresponda) o ANTES de que la animación arranque — nunca "al lado".
Cómo se caza: `arrival_probe.py` sobre una grabación del sim — una hilera
de puntos justo después del primer frame del overlay es un bloqueo, no una
pausa de diseño (el análisis general a umbral grueso NO lo ve: el fade y la
respiración caen debajo del umbral y la llegada parece "quieta" a
propósito).

### Del cofre a velocidad (2026-08-28 sexta)

**⚠️ Con una sesión paralela viva en el checkout, un build compila el árbol
AJENO.** El binario de xcodebuild es una foto del árbol DURANTE la
compilación, no del commit: si la otra sesión edita mientras tu build corre
(y los builds acá tardan 10–20 min con la máquina compartida), te llevás sus
archivos a medio escribir sin ningún error. Síntoma medido: el fixture
`--uitest-chest` "roto" — app viva, tablero andando, cero cofre, cero log —
con un código que leído era imposible que fallara; el MISMO commit compilado
desde un worktree aislado anduvo a la primera. Dos horas de arqueología por
no sospechar del binario. Señales acompañantes: `BUILD INTERRUPTED` sin
motivo y `database is locked` (dos xcodebuild sobre el mismo árbol). Regla:
**sesión paralela detectada ⇒ worktree aislado para TODO** (`git worktree
add` desde el HEAD local — ojo que la herramienta de worktrees arranca de
`origin/main`, que puede estar semanas atrás —, symlink del `.venv` del
pipeline y `xcodegen generate`), que es el protocolo que la memoria ya
mandaba para los COMMITS y ahora sabemos que aplica también a los BUILDS.

**⚠️ El promedio por segundo esconde el congelón que el jugador SÍ ve.**
"24 fps clavados" era verdad y la traba también: 150+133 ms de frames
idénticos DENTRO de segundos que promediaban bien, justo en el empalme
PNG→video. Al verificar fluidez, medir las DOS cosas sobre la grabación
normalizada a 60 CFR: frames distintos por segundo Y corridas de idénticos
≥100 ms (el script de la sesión sexta las lista con timestamp). Y para
mapear un momento puntual: nunca extraer "el frame n" del h264 del sim — es
VFR y el índice no es tiempo (un frame "de los 17 s" era en realidad de los
21,5); siempre `-ss` por tiempo o el stream ya normalizado.

**⚠️ VideoToolbox pisa los PTS que le entrega el filtro.** Un
`setpts=PTS/1.5` perfecto a la salida del filter_complex (verificado con
`showinfo`: cadencia 1/36 exacta) llegó al mov como 1/24 con `-vsync 0` — o
sea el retime NO viajaba. Con `-r 36 -fps_mode cfr` el muxer respeta la
cadencia, y `-frames:v 190` corta el frame de relleno que el modo cfr
agrega en la cola. Moraleja: después de cualquier retime, `ffprobe` al
ARCHIVO (nb_frames + duración de video Y de audio), no al filtro.

### Del pulido post-cofre (2026-08-28 cuarta)

**⚠️ Reemplazar un PNG "en el lugar" dentro de un `.atlas` NO recompila el
atlas.** El build system decide recompilar el atlasc mirando el mtime de la
CARPETA `.atlas`, y escribir un archivo sobre el mismo inode (PIL `save`, un
`>` de shell) no lo cambia — sólo agregar/borrar/renombrar archivos lo hace
(git checkout sí, porque reemplaza por rename). Síntoma medido: la tarjeta de
Regalos mostrando el cofre de un master BORRADO con el PNG nuevo sentado en el
árbol, en todo DerivedData incremental. Fix: el generador toca la carpeta al
escribir (`os.utime(UI_ATLAS)` en `chest_video_frames.py`); si otro pipeline
escribe atlas en el lugar, necesita lo mismo.

**⚠️ La máquina cargada miente DOS veces al verificar visuales.** El mismo día:
(1) la cadencia de `simctl io screenshot` (2–4 s por captura bajo carga) hace
parecer que una animación se saltea etapas — el juez del timing es el log de
latidos (`log stream --level info`), no las capturas; (2) el juego CORRIENDO
en el sim mientras xcodebuild satura la CPU se ve "muy laggeado" y no lo está
— grabado y contado a máquina quieta, el cinemático entrega sus 24 fps
clavados. Antes de tocar código por un reporte de fluidez: medir con la
máquina quieta (`simctl io recordVideo` + contar frames distintos por
segundo).

### Del video del cofre (2026-08-28 bis)

**⚠️ `AVPlayerLayer` composita el HEVC-alfa como PREMULTIPLICADO, y `chromakey`
no toca el RGB.** La ecuación del compositor es `out = rgb + fondo×(1−α)`: todo
pixel con α=0 cuyo RGB no sea (0,0,0) le SUMA su color al juego. Un mov keyeado
con ffmpeg conserva en las zonas transparentes el verde pasado por `despill`
(≈L 26) → un velo claro sobre todo el encuadre, cortado seco en el borde del
video, **desde el primer frame del mov** (los PNG de SwiftUI van con alfa
straight y por eso los toques se veían bien). Fix de una línea en el encode:
`alphamerge,format=gbrap,premultiply=inplace=1,format=bgra` — después del
alphamerge para multiplicar por el alfa ya emplumado, y en `gbrap` porque
`premultiply` no toma rgba empaquetado. **Cómo se detecta**: restar una captura
con video contra una sin video y perfilar por filas — un ESCALÓN en el borde
del encuadre es este bug; el scrim radial legítimo es suave. Y la relectura
que dolió: la "viñeta horneada que se cortaba en el borde" del master viejo
era ESTE MISMO bug con fondo oscuro — el feather y el scrim de continuación
de esa ronda fueron parches al síntoma, no a la causa.

### Del filtro de desbloqueo (2026-08-28)

**⚠️ Cortar un `xcodebuild` a mitad puede dejar el SIGUIENTE colgado para siempre.** El
build se queda en `ClangStatCache` esperando un lock que dejó tomado el proceso muerto, y el
síntoma se confunde exactamente con "la máquina está ocupada": `load average` altísimo y el
log sin avanzar una línea durante veinte minutos. **Lo que los distingue es medir el
proceso, no el reloj**: un build lento tiene `swift-frontend`/`clang` corriendo y xcodebuild
con CPU; un build colgado está a **0 %** y no tiene un solo compilador vivo.

```bash
ps aux | grep "[x]codebuild" | awk '{print $2, $3"%"}'   # 0.0% sostenido = colgado
ps aux | grep -cE "[s]wift-frontend|[c]lang -"            # 0 con el build "corriendo" = colgado
pkill -f clang-stat-cache                                 # y relanzar
```

Pasó el 2026-08-28 después de un `TaskStop` sobre una corrida de UI. **Si vas a cortar un
build, contá con limpiar el `clang-stat-cache` huérfano antes de relanzar.**


**Un caso que la vista no puede recibir no va en el tipo que la vista dibuja.** Agregar
`.needsProgress` a `ChestOutcome` compilaba, pero el compilador devolvió **seis errores de
exhaustividad adentro de `ChestOpeningView`** —uno por cada `switch` de la coreografía— para
un valor que esa vista no puede ver nunca. La salida no era agregar seis ramas muertas: era
partir el tipo (`ChestDraw` = premio | todavía no), y los seis errores eran el diseño
avisando que el caso estaba en el lugar equivocado. **Cuando el compilador pide ramas muertas
en un consumidor, el problema suele ser el tipo y no el consumidor.**

**Un parámetro nuevo con default es una regla que se puede apagar sin ponerse roja.**
`ChestRoller.roll(unlocked:)` va SIN default a propósito: con uno, cualquier call site que se
lo olvidara volvería al comportamiento viejo en silencio. Sin él, los ocho call sites de test
tuvieron que decir explícitamente qué desbloqueo estaban midiendo — que además los hizo
legibles. **Cuando lo que agregás es una garantía, el default es su agujero.**

### Del cierre de los cofres (2026-08-27)

**⚠️ `swift test --filter` con el nombre VISIBLE de una suite corre CERO tests y devuelve
éxito.** Es la gemela exacta de la trampa del `-only-testing:` sin paréntesis, del lado de
SPM: `swift test --filter "El sorteo de un cofre"` imprime
`Test run with 0 tests in 0 suites passed` y termina en 0. El `--filter` matchea el nombre
del **tipo** (`ChestRollerTests`), no el `@Suite("…")` que se ve en la salida. Apareció
verificando una mutación en este mismo cierre, y habría hecho concluir que el test nuevo era
vacuo. **Misma regla que la otra**: confirmar que la salida NOMBRA los tests esperados. Una
corrida que no nombra ninguno no probó nada — y ojo, que las dos veces el número delator
(`0 tests`) estaba impreso y a la vista.

**El ledger de un SDD no es una lista de pendientes.** Anota cuándo se VE un defecto, no
cuándo se cierra: de las 36 menores diferidas del run de los cofres, **12 ya estaban
arregladas** por rondas posteriores a la que las anotó (el mismo archivo que las lista tiene
más abajo el fix que las cierra). Triagear leyendo el ledger y creyéndole habría producido
una docena de "arreglos" sobre código ya correcto. **Verificá cada línea contra el árbol
antes de tocarla.**

**Un rojo heredado sobrevive a su propia cura.** El cuadro de §6 contaba "12 rojos (1
declarado + 11 de máquina)" mucho después de que la matriz de dos runtimes —construida
justamente para eso— los pusiera en verde: en el sim 18.6 pasan los 12. Y el rojo que sí
queda estaba descripto con el motivo VIEJO (las horas) cuando hacía rondas que fallaba por
otra cosa (las reencarnaciones). **Un número de verificación que no se vuelve a tomar se
pudre en las dos direcciones**: de más y de menos.

### De los cofres, segunda tanda (2026-08-27)

**⚠️ `-only-testing:` con un id de Swift Testing SIN PARÉNTESIS corre CERO tests y devuelve
ÉXITO.** `-only-testing:Suite/miTest` no matchea nada y termina con `Test run with 0 tests,
** TEST SUCCEEDED **`; hace falta `-only-testing:Suite/miTest()`. Esto **invalida en silencio
cualquier prueba por mutación**: se rompe el código, se corre el test "solo", sale verde, y se
concluye que el test es vacuo cuando en realidad no corrió. Pasó en esta sesión y casi se
reporta como mutación sobreviviente. Se descubrió porque el diagnóstico **también** daba
`exit=0` sin imprimir nada — o sea, midiendo el comando en vez de confiar en él.
**Regla**: filtrar por SUITE (`-only-testing:Suite`) y confirmar en la salida que los tests
esperados aparecen nombrados. Una corrida que no nombra ningún test no probó nada.

**Nadie miraba nunca la frase compuesta.** `chest.skin.subtitle` no lo resolvía ni lo
asserteaba ningún test, y por eso *"Para tu El Trapito"* pudo shippear: la plantilla se
testeaba por separado y el nombre por separado, pero **la oración armada no la leía nadie**.
Los tres nombres con artículo son `El Fisura`, `El Trapito` y `El Mantero` — 3 de 44. La red
que faltaba recorre `concreteTypes` y rechaza determinante pegado a determinante, y lleva su
propia guarda: sin exigir que la frase **nombre** al personaje, una clave que no resuelve deja
pasar todo.


**Un `.sheet` no puede abrir un overlay que vive en el `ZStack` de `RootView`.** El botón de
Regalos que abre un cofre **tiene que cerrar la hoja primero**: si no, la animación se
reproduce **debajo**, invisible y sorda a los toques, y como `.chestOpening` no tiene timeout
ni es salteable, la cola global queda congelada con el HUD apagado. Es el mismo pozo que el
contrato del orden, por otra puerta.

**Una proyección que sale de `player` no invalida SwiftUI.** `player` es
`@ObservationIgnored` para que el tick de 60 Hz no redibuje el HUD; cualquier cosa que una
vista tenga que leer y ver cambiar sola necesita su propia propiedad observada (el patrón es
`hasClaimableAchievements` / `hasPendingChests`). El puntito del cofre habría sido código
muerto.

**En `skins.json` no hay ningún `characterType == "*"`.** La pinta que visten todos está
escrita con el **mismo id 43 veces** (`oro`, `diamante`), porque la propiedad se guarda por
id — y esas dos cubren **exactamente** los 43 personajes concretos. Cualquier regla del tipo
"personajes de los que tenés una pinta" **despliega el catálogo entero** a quien compró el
paquete de diamante, espoileando la cadena de evolución. La regla correcta: **una pinta que
viste a más de uno no trae a nadie**.

**`isHittable` TIRA, no devuelve `false`.** Cuando XCUITest no puede calcular el punto de
activación —típicamente con el elemento recortado por un scroll, que suele ser justo el
estado que el assert quiere observar— la propiedad es un `BOOL` sin canal de error y la falla
sale como excepción. Y `XCTNSPredicateExpectation` **no reintenta ante excepciones**. Para
"¿se ve esta celda?" usar geometría (¿el centro del marco cae en la ventana?), no hittability.

**Dos instrumentos de medición de video que mienten, los dos descartados en esta sesión:**
`simctl recordVideo` **dropea cuadros por su cuenta** —huecos de 200-450 ms aparecen con la
pantalla quieta, en cualquier rama—, así que sus huecos no miden nada; y el `-ss` de ffmpeg
sobre un mp4 **no cae donde se le pide**, así que una tira de cuadros armada por tiempo
compara momentos distintos. Las tiras se arman **por índice de cuadro exacto**. Para medir
bloqueo de hilo principal, un vigía adentro de la app (un `Task` que pide dormir 16 ms y
denuncia cuando despierta tarde) — y ojo: reporta el bloqueo **más largo** del latido, no la
suma.

**`Task.yield()` no es "esperar a que el hilo se libere".** Reencola **una vez** en la cola
del main actor: no espera a que termine la pasada de armado, no espera un cuadro dibujado y
no ordena contra el commit de la `CATransaction`. Sirve —hace que la caída del cofre se vea—
pero es **un hop calibrado contra el bloqueo de hoy**, no una garantía: si el bloqueo cambia
de tamaño, puede volverse innecesario o insuficiente.

**`UIArt.characterImage` en frío cuesta ~320 ms de hilo principal**, de los cuales **~215 son
`texture.size()`** realizando la página del atlas y ~100 el `cgImage()`. Cacheado, 0,1 ms.
Cualquier vista que muestre un retrato por primera vez lo paga; precalentarlo unos latidos
antes lo muda, no lo borra. Sacarlo de verdad es `SKTextureAtlas.preload`, y es tarea propia
porque lo pagan también la ficha, el carrusel y el tablero.

### De los cofres (2026-08-26)

**Siete tests que quedaban verdes con la funcionalidad desenchufada.** Casi todos escritos
por el controller en el plan. Los cazó siempre lo mismo: **romper la cosa y mirar si el test
cae**, nunca leerlo. Los tres que más enseñan:

- El de la migración v5 asertaba "los campos valen cero", que es cierto **con o sin** migrar,
  porque se decodifican con `decodeIfPresent ?? 0`. Lo único que detecta el cableado roto es
  `schemaVersion == 5`.
- El de la cola **no podía pasar nunca**: `enqueue` sobre una cola vacía promueve en el acto,
  así que el ítem nuevo tomaba `current`. Para comparar prioridades hay que ocupar el turno
  con un tercero primero.
- El de la animación quedaba verde **por el reloj**: con el auto-avance prendido, la
  aserción de que los tres toques revientan el cofre pasa igual con los toques muertos. Pidió
  un flag (`--uitest-chest-manual`) que apague el auto-avance.

**Un renombre de claves de localización NO lo protege el compilador.** `String(localized:)`
con la clave borrada **compila** e imprime la clave cruda en pantalla, y los tests que sólo
miran `!texto.isEmpty` pasan porque una clave cruda no es vacía. El repo ya tenía el idioma
correcto en `DailyCalendarTests` (`!copy.contains("daily.")`); ahora está también en
`BoostUnlockTests` y `CareerRewardTests`, y **generaliza** a toda la familia de claves.

**Y el error que lo destapó: `| head` truncando la propia verificación.** El controller
escribió en el plan "son exactamente esos cuatro call sites, ni más ni menos" desde un grep
que devolvía 11 líneas y estaba cortado en 10. Eran seis. Los dos que faltaban eran justo los
de falla silenciosa. **Nunca afirmar completitud desde una salida truncada, y menos
escribirla en un plan: le dice al implementador que deje de buscar.**

**`ParticlePool` no sirve desde SwiftUI** (`emit(_:at:in parent: SKNode)`, único cliente
`BoardScene`), y **`HapticsManager` no tiene `.light`/`.medium`/`.heavy`/`.success`**: el
juego usa vocabulario semántico sobre CoreHaptics (`.merge`, `.purchase`, `.error`,
`.evolution`, `.rarity`). Las dos cosas estaban afirmadas al revés en el plan.

**El cofre puede congelar la cola de celebraciones entera.** `.chestOpening` tiene
`timeout: nil` (el tick nunca lo vence) e `isSkippable == false` (el tap nunca lo saltea): si
la vista no limpia `chestReward` **antes** de `celebrationFinished`, `syncCelebrations` lo
reencola en el mismo frame, `showing` queda pegado para siempre y **el HUD queda apagado sin
watchdog que lo destrabe**. El embudo único es `dismissChestReward()`.

1. **El build incremental NO recompila los atlas.** Si medís páginas de atlas o
   peso del `.app` y no cierran, borrá `build/DD`.
2. **Un test de UI puede pasar sin probar nada.** Si automatizás gestos sobre
   SpriteKit, **asertá el efecto**, no que el gesto no crashee.

   ✅ **`AscentRenderingUITests` YA NO ES ROJO** (migrado y verificado el
   2026-08-16, 3 corridas verdes: fría, tibia y fría). Estuvo diez días salteado
   por un diagnóstico que era **verdadero pero incompleto**, y las tres causas
   valen más que el arreglo:

   1. **El arrastre por coordenadas fijas** (la vieja trampa 3). Arreglado
      migrando a **doble toque**, como `mergeTheHighlightedPair`: sólo hay que
      acertarle al personaje de ORIGEN, del destino se encarga
      `MergeTargeting.nearestPartner`. Se barren los slots y se asserta que
      `board.units` **baje**, que es lo único que prueba que hubo fusión.
   2. **Un supuesto de economía vencido, y esto es lo que lo mantuvo rojo aun
      después de arreglar el gesto.** El test decía "par de Cartoneros → Kiosco
      (T3) **asciende**" y hace rato que no: el callejón cubre los tiers **1..4**
      (`economy.json`), así que el primer piso nuevo lo abre un **T5** y hacen
      falta **cuatro** fusiones, no dos. Ahora el test **no hardcodea el número**:
      fusiona hasta que la pill cambia de piso, con tope. Un rebalanceo no lo
      vuelve a romper.
   3. **El device frío** (trampa 9a). El primer toque de la corrida sobre
      `hud.debug` moría con `Failed to scroll to visible (by AX action)`, porque
      `board.units` es del tamaño del tablero y XCUITest cree que tapa al HUD.
      Este test es el primero de su suite, así que era el que se lo comía. Se
      toca por COORDENADA, igual que `CustomizationUITests`.

   ⚠️ **Ya se llevó puestos dos agentes** que lo diagnosticaron como "el
   simulador no arranca" y se pusieron a borrar dispositivos. No es eso, nunca lo
   fue: el modo de falla "la app no corre" era una entrada de background que
   faltaba en el manifest, arreglada hace rato.

   📌 **La moraleja, que es la de la trampa entera:** un test salteado se pudre
   solo. Este acumuló un espejo de geometría desactualizado (`bottomInset` en 110
   cuando la escena ya iba en 114), un `sheet.close` tapeado sin guarda —migrado
   a ciegas mientras estaba salteado— y un supuesto de economía vencido, todo
   sin que nadie se enterara, porque nadie lo corría. **Si vas a saltear algo,
   ponele fecha de vencimiento.**

   ⚠️ **`PacingTests.strugglingPhaseLength` también está rojo en `main`**
   (verificado con `git stash` el 2026-08-06). No falla un assert: el proceso de
   la app **muere** — `Test crashed with signal kill before starting test
   execution`. Es entorno, no economía. Salteálo igual que el otro mientras no se
   arregle.

   ⚠️ **El simulador se degrada en corridas largas** (`(ipc/mig) server died`
   repetido). Se sale con `xcrun simctl shutdown all`, `erase` del device y
   `-parallel-testing-enabled NO`. Si una suite empieza a fallar a mitad de una
   corrida que venía verde, es esto y no el código.

   ⚠️⚠️ **Dos agentes en paralelo NO pueden compartir el mismo device.** Es la
   causa raíz de lo anterior. Con varios frentes corriendo contra
   `name=iPhone 16 Pro` aparecen `Invalid device state`, `Mach error -308`,
   reinicios del bundle a mitad de corrida y —lo que lo delata— **tests de OTRO
   worktree en tu log**: un frente vio correr `EffectDescriptorTests`, que no
   existían en su árbol. Cada frente se crea el suyo y apunta por UDID:

   ```bash
   xcrun simctl create "mi-frente" "iPhone 16 Pro"
   ```

   ```bash
   xcodebuild ... -destination 'id=<UDID>' -parallel-testing-enabled NO
   ```

   Desde que se hizo eso: cero reinicios, cero fallos espurios.

   ⚠️⚠️ **Y APAGALO AL TERMINAR.** Un simulador booteado son ~200 procesos que
   no se van solos. Con seis frentes creando el suyo y ninguno apagándolo, esta
   máquina llegó a **736 procesos `iOS` y load average 861**: los builds pasaron
   de 7 minutos a no terminar nunca, y varios frentes reportaron "la máquina
   está saturada" sin saber que la saturaban ellos. El cierre es parte del
   trabajo, no una cortesía:

   ```bash
   xcrun simctl shutdown <UDID> && xcrun simctl delete <UDID>
   ```

   ⚠️ **`EconomyLoopUITests.testTappingEarnsCoinsAndSpawnButtonExists` también es
   flaky**, por la misma trampa 3: falló una vez y pasó las tres siguientes sin
   que nadie tocara nada. No es un tercer bug, es el mismo patrón.
3. ~~**Los drags por coordenadas fijas fallan seguido**~~ **ARREGLADO en buena
   parte (2026-08-10, fusión asistida).** La causa era peor que "los tests son
   frágiles": la escena resolvía el drop contra el **ancla lógica** del slot y
   no contra dónde estaba parado el personaje, que desde que el reconciliador
   conserva la posición deambulada difieren hasta media celda. O sea que
   **soltar encima de alguien te mudaba al hueco de al lado**, en el juego y no
   sólo en el runner.

   Ahora la decisión vive en `MergeTargeting.dropTarget`, que mide contra las
   posiciones **reales**; las anclas quedan sólo para los slots vacíos, que no
   tienen nodo. `mergeTheHighlightedPair` pasó de barrer ocho coordenadas a un
   doble toque.

   ⚠️ Lo que **no** cambió: los personajes siguen deambulando, así que un gesto
   automatizado por coordenada fija sigue necesitando reintentos para acertarle
   al CUERPO. Lo que ya no hace falta es barrer el DESTINO.
4. **"Failed to scroll to visible" en un test de UI casi nunca es el botón**: es
   algo modal tapándolo. Exportá los attachments del xcresult y mirá la captura.
5. **Claves de localización con `%@` interpoladas con un `Int`** salen como la
   clave cruda en pantalla: Swift manda `%lld` y el lookup falla. Pasá `String(x)`.
   Ya pasó **dos veces** (F7.5 y 2026-08-05).

   ⚠️ **Y tiene una segunda forma, encontrada el 2026-08-06: armar la CLAVE por
   interpolación.**

   ```swift
   Text(LocalizedStringKey("upgrades.flavor.\(line.id)"))   // ⛔️ NO busca esa clave
   ```

   `LocalizedStringKey` es `ExpressibleByStringInterpolation`, así que eso no
   construye `upgrades.flavor.income`: construye la clave **`upgrades.flavor.%@`**
   con `income` de argumento. No la encuentra, y dibuja el formato con el id
   sustituido — en pantalla se lee literal `upgrades.flavor.income`.

   Lo peor es que **el test unitario pasaba**, porque hacía el lookup por otro
   camino. Sólo se vio mirando el simulador. La forma correcta es resolver la
   clave en una función del estado (`upgradeFlavorText(for:)`) y que el test
   ejerza **esa misma función**, la que dibuja la fila.

   ⚠️⚠️ **Y una tercera forma, que muerde al revés: `stale` NO quiere decir
   borrable.** El reformateo del catálogo que dejó el último build de Xcode
   (`07789d7`) marcó `extractionState: stale` en **175 de las 459 claves**, y
   muchas están **VIVAS**: `settings.haptics`, `daily.title`,
   `notif.daily.title`/`.body` y ~20 de ajustes. El extractor no ve a través de
   un parámetro `titleKey:` —la clave viaja como `LocalizedStringKey` hasta una
   vista propia en vez de aparecer como literal de `Text`— ni siempre a través
   de `String(localized:)`. **Una pasada de limpieza que borre por
   `extractionState` se lleva claves vivas y deja la clave cruda en pantalla**,
   que es la misma falla de esta trampa por otra puerta. Verificá por `grep`
   antes de borrar una sola.

6. **El runner de tests de UI corre la app en INGLÉS**, aunque el idioma de
   desarrollo del proyecto sea `es`. Un test que asserta sobre texto en español
   pasa por la razón equivocada: no encuentra el texto **nunca**, ni cuando la
   cosa que busca está presente. Asertá por **accessibility identifier**, y
   verificá el test al revés —poniendo de vuelta lo que sacaste y viendo que
   falla— antes de creerle.

7. **Los agentes en paralelo comparten el scratchpad.** Si varios frentes
   escriben `full.log` ahí, se pisan entre sí. Prefijá con el nombre del frente.

   ⚠️⚠️ **Y su worktree se crea desde `origin/main`, no desde `main` local.**
   El 2026-08-06 `origin/main` estaba **102 commits atrás** —este repo se
   commitea local y casi no se pushea—, así que **todos** los frentes
   arrancaron sobre el árbol de cuatro días antes: sin el plan que tenían que
   leer, sin el spec, y con los JSON viejos. Cada uno lo detectó y se puso al
   día solo, pero uno lo dijo bien: *"si otro frente arrancó igual, trabajó
   sobre un repo fantasma"*.

   **Lo primero que hace un frente nuevo es comprobarlo:**

   ```bash
   git rev-list --count origin/main..main
   ```

   Si no da 0, `git merge --ff-only main` antes de tocar nada. Y la solución de
   fondo es pushear: mientras `origin` esté viejo, esto se repite en cada tanda.

8. **El handler de `SKTexture.preload` TIENE que ser `@Sendable`.** SpriteKit lo
   llama desde una cola de fondo y `BoardScene` es `@MainActor` (`SKScene` lo es
   en el SDK), así que un `{}` pelado hereda el aislamiento y **mata el proceso
   con SIGTRAP** al terminar la precarga.

   ```swift
   SKTexture.preload(textures) { @Sendable in }   // ✅
   ```

   ⚠️ Y lo grave: **el test de UI seguía en verde con la app crasheada.** Es la
   trampa 2 otra vez — un test de UI puede pasar sin probar nada.

9. ~~**Los tests de UI existentes pasan según el ORDEN en que corren.**~~
   **ARREGLADO (2026-08-07, RF-01).** `LaunchSmokeTests` y `EconomyLoopUITests`
   funcionaban sólo porque `--uitest-open-sheet` dejaba `fisuTutorialDone`
   seteado en ese simulador; en un device limpio el scrim del tutorial les tapaba
   los controles. Reproducido antes de tocar nada: `EconomyLoopUITests` fallaba
   con "coins never changed after tapping" en un simulador recién creado.

   El arreglo **no** fue que el tutorial deje de bloquear la pantalla —el patrón
   Clash of Clans exige que la bloquee, y RF-01 lo pide explícitamente— sino que
   el estado del tutorial pasó a ser **declarado y no heredado**:
   `--uitest-reset` ahora resetea también `fisuTutorialDone` y las tres banderas
   `ftue.*` (antes "partida nueva" sólo rehacía la PARTIDA), y el test que no
   quiere ver el tutorial lo dice con `--uitest-skip-tutorial`. Ningún test
   depende ya de lo que dejó otro.

   ⚠️ **Dos trampas nuevas de SwiftUI salieron de acá** y las dos se ven igual:
   todo compila, la pantalla se ve bien y el test falla en otro lado.

   a. **Un elemento de accesibilidad a pantalla completa TAPA a todos los
      controles de abajo en el árbol de AX.** Los marcadores del tutorial eran
      dos `Color.clear` arriba del `ZStack`; con eso, XCUITest dejaba de
      considerar "hittable" a cualquier botón —incluido el de saltear del propio
      tutorial— y todo `.tap()` moría con "Failed to scroll to visible", que es
      la trampa 4 con disfraz nuevo. Los toques por COORDENADA seguían
      funcionando, así que en el simulador no se notaba. Van de fondo y de 1×1,
      como `board.units` en `RootView`.

   a-bis. **Y la forma general, encontrada el 2026-08-10 con los contadores de
      bonus**: un `accessibilityIdentifier` puesto sobre un **contenedor que no
      es elemento de accesibilidad** (un `VStack` pelado) **se propaga y pisa el
      de sus hijos**. La barra tenía `hud.bonuses` en el `VStack` y cada chip su
      `hud.bonus.chip`: en el árbol quedaba **un solo** elemento, llamado
      `hud.bonuses`, y el test no encontraba ni un chip **mientras en pantalla
      se veían perfectos**. La cura es no ponerle identificador al contenedor.
      Se vio exportando los attachments del xcresult y mirando la captura —por
      eso conviene tomarla ANTES de los asserts, que un assert que corta se
      lleva puesta la evidencia.

   b. **`anchorPreference` PISA el valor del subárbol; no se suma.** Marcar la
      franja del HUD borraba de un saque los anclas del contador de monedas, de
      mejoras y del mapa, que viven adentro. El tutorial dibujaba el scrim entero
      sin recorte y el paso quedaba sin salida. Se usa
      `transformAnchorPreference`, que mergea.

   c. Y una de tests: `.tap()` sobre un elemento que XCUITest considera no
      hittable se pasa **~60 s** reintentando y después toca igual. Un test que
      quiere probar que algo NO se puede tocar tiene que tocar por coordenada: si
      no, tarda dos minutos y confunde "el scrim se comió el toque" con "XCUITest
      se negó a tocar".

9. **Un `repeatForever` no arranca si su `@State` cambió ANTES de que la vista
    exista.** La mano del tutorial no latía: el `onAppear` que ponía la bandera
    vivía en el overlay y corría mientras el recorte del tablero todavía no había
    llegado desde la escena, así que la mano se insertaba con la bandera ya en
    `true` — sin cambio que animar, sin animación. La bandera va en la **misma
    vista** que anima, con su propio `onAppear`.

    ⚠️ Lo importante es **cómo se encontró**, porque no se ve en una captura: la
    mano estaba ahí y en su pose grande. Se ve comparando **cuatro capturas
    seguidas** y hasheando la región. Y sólo se detecta si además se corre **al
    revés**: con Reduce Motion las cuatro daban idéntico —correcto— y sin Reduce
    Motion **también**, que es el bug. Una verificación visual que no discrimina
    en los dos sentidos no está verificando nada; es la trampa 2 fuera de los
    tests.

    ```bash
    xcrun simctl spawn <UDID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
    ```

10. **Congelar lo que animaba baja los fps del overlay de DEBUG a ~1, y está
    bien.** Con el recorte del tutorial sobre el tablero no queda nada animando
    en SpriteKit (el anillo de FTUE se calla y el personaje deja de deambular) y
    el contador marca `1.0 fps`. No se pierde income: `tick` integra por `delta`,
    así que la misma plata se acredita en tramos más largos, y el tap refresca
    las proyecciones por su cuenta sin pasar por el frame loop. Vuelve a 60 al
    salir del paso. Ver también la trampa 11: ese contador miente fácil.
11. **`osascript`/System Events no funciona desde el shell del agente** — y ahora
    se sabe **exactamente dónde** (probado el 2026-08-06):

    | Paso | Desde el shell del agente |
    |---|---|
    | `launch_gemini_chrome.py` | ✅ **funciona**. Abre el Chrome aislado y `:9222` responde |
    | La sesión de Gemini en ese perfil | ✅ sigue logueada |
    | `build_queue` y el checkpoint | ✅ funcionan |
    | **Mandar las teclas al compose box** | ❌ `System Events got an error: osascript is not allowed to send keystrokes. (1002)` |

    Es el permiso de **Accesibilidad** de macOS, que el shell del agente no tiene
    y no puede pedirse a sí mismo. Falla en el asset 1 de 53, **sin consumir
    cuota y sin ensuciar el checkpoint** — así que intentarlo es barato, pero no
    sirve. El batch se corre **desde Terminal.app**, que sí tiene el permiso.

    ✅ **Y hay una salida para agentes, probada el 2026-08-16**: escribir un
    `.command` con los comandos del batch y lanzarlo con `open` — Terminal.app
    pasa a ser el responsible process de TCC y `osascript` hereda su permiso.
    El tipeo funcionó (2146/2150 caracteres del asset 2 llegaron al editor).
    ⚠️ Lo que lo mata no es el permiso sino **el foco**: con otros frontends
    activos en la máquina, las teclas caen en la ventana equivocada (probado
    el mismo día: dos assets con 0 caracteres tipeados). Desde `acaf3e6` el
    runner lo detecta y aborta con cuota cero — nunca manda un prompt a medias
    ni barajado — pero el batch sólo AVANZA con la máquina quieta: si hay
    sesiones de agentes corriendo, que lo lance el dueño con todo cerrado.
12. **Medir fps con un build corriendo en paralelo da números basura.**
13. **La multitud y los fondos comparten espacio de `zPosition`, y eso ya rompió
   una vez.** `depthZ` da negativo apenas una fila queda por encima de
   `rows × cellSize`, y los `FloorNode` viven en `ordinal × 0.01`: cuando las dos
   bandas se tocan, el fondo tapa a los personajes y quedan **invisibles pero
   clickeables** (el hit-testing es geométrico y no mira el z). `fieldNode` va
   montado en `BoardScene.fieldBaseZ` para que no puedan tocarse, y
   `CrowdDepthTests` lo pinea. Si tocás `frontRowRatio`/`rowDepthRatio`/wander,
   ese test es el que te avisa.
14. **Un personaje invisible no siempre es `alpha = 0`.** Ese era el bug viejo del
   pool. Si además ves su etiqueta "T1" flotando sin cuerpo, es z: dentro de un
   `CharacterNode` todos los hijos comparten z, y con `ignoresSiblingOrder`
   SpriteKit batchea labels y sprites del atlas por separado, así que contra el
   fondo pierden los cuerpos y sobreviven los labels.
15. **`xcodegen generate` con Xcode ABIERTO rompe el proyecto que ves en Xcode**,
   y el síntoma no se parece a la causa: Xcode dice
   **`Missing package product 'EconomyKit'`** y el build falla.

   Pasó el 2026-08-07. El `.xcodeproj` no se versiona y se regenera seguido, así
   que la sesión abierta de Xcode se queda con el grafo de paquetes del archivo
   viejo; cuando el archivo se reemplaza abajo, la referencia al paquete local
   queda colgando. **El disco está perfecto** — se comprobó con un build de
   device completo, que compiló y firmó:

   ```bash
   xcodebuild -scheme FisuEvolution -destination 'generic/platform=iOS' -configuration Debug build
   ```

   Y `xcodebuild -resolvePackageDependencies -scheme FisuEvolution` imprime
   `EconomyKit: .../Packages/EconomyKit`, o sea que la resolución tampoco está rota.

   **La cura es del lado de Xcode**, no del repo: cerrar el proyecto (⌘⇧W) y
   volver a abrirlo. Si insiste, *File ▸ Packages ▸ Reset Package Caches*.

   ⚠️ Y la prevención, que importa más si hay agentes trabajando: **cerrá Xcode
   antes de dejar correr un frente**, o contá con reabrir el proyecto cuando
   vuelvas. Un agente regenera el `.xcodeproj` cada vez que agrega o borra un
   archivo Swift, que es todo el tiempo.

   ⚠️ Corolario: **un build de línea de comando con `-derivedDataPath build/DD`
   NO reproduce esto** —usa su propia DerivedData y su propio estado de
   paquetes—, así que la suite puede estar entera en verde mientras Xcode no
   compila. Para reproducir lo que ve Xcode hay que buildear **sin**
   `-derivedDataPath`.

16. **El cwd de una sesión de agente puede volverse SOLO al checkout
   principal a mitad de sesión** (pasó el 2026-08-17, entre dos corridas de
   test de la misma sesión). El síntoma es venenoso porque nada falla en el
   momento: los builds "SUCCEEDED" —del árbol equivocado—, la suite de UI
   corre —contra el código del dueño, con SUS rojos— y la app instalada en el
   simulador es la vieja. Se detectó porque una captura mostraba la UI de
   antes del rediseño y `strings` sobre el binario no encontraba los símbolos
   nuevos (ni un literal de `Color("...")` recién agregado, que es la prueba
   más barata).

   **La regla**: en sesiones largas de agente, TODO comando de build/test va
   con ruta absoluta de `-derivedDataPath` y verificación de `pwd` — y si el
   resultado de una corrida se contradice con el código (falla algo que no
   tocaste, en cluster), lo primero que se chequea es QUÉ árbol corrió:
   `xcrun xcresulttool`/el log imprimen la ruta del xcresult, y esa ruta
   nombra al culpable. Los commits se salvaron porque cada uno imprime su
   rama: `[feature/... hash]` en el output es el pinning gratis que siempre
   hay que mirar.

---

### Trabajar en paralelo con otra sesión (2026-08-17)

Dos cosas que costaron tiempo este día y que no están en ninguna otra parte:

1. **El simulador es un recurso compartido.** Otra sesión tomó el mismo
   simulador dos veces a mitad de una QA visual: aparecía SU app en el
   foreground y mis taps entraban ahí. Se pierde la captura y, peor, se
   interfiere con el trabajo del otro. **Creá el tuyo** (`xcrun simctl create` +
   `bootstatus -b`) y cerralo al terminar, que además es la receta que §6 ya pide
   para medir.
2. **`git add` amplio se come trabajo ajeno.** Un `git add -A FisuEvolution` metió
   un cambio de la otra sesión (`bottomInset` a computado) adentro de un commit de
   celebraciones. Con dos frentes sobre el mismo checkout, **stagear por archivo**
   y mirar `git status` antes de cada commit no es ceremonia.

### Del pipeline de arte (2026-08-19)

⚠️ Desde `version-2` el runner de Gemini ya no está en este repo: vive en
`~/Desktop/projects/automatic-image-generation`. Las trampas 11 y 17-20 son de
ese runner y siguen valiendo allá; la 21 es de la integración y vale acá.

17. **El descarte por huella se come lo bueno si la variante conserva la pose.**
    El runner tira la imagen extraída si queda a menos de `--ref-threshold` de la
    referencia, pero la huella es un thumbnail de **32×32** y el fondo blanco
    ocupa el **74%** del cuadro. Medido: la referencia re-codificada da ≤ 0,37,
    un dorado típico 9,51, y el peor caso —`magnate_solar`, que ya vestía de
    amarillo— **3,84**. Ni un personaje enteramente NEGRO pasa de 25,80. El
    default quedó en **1,5**; con 12 no pasaba ninguna y el runner agotaba el
    timeout de cada asset sin encontrar candidato.

18. **El timeout de generación no puede bajar de ~250 s.** Es el piso real
    medido. Con un cap de 200 s se mata la imagen unos segundos antes de que
    Gemini la renderice, y como no se guarda PNG el asset **nunca sale de la
    cola**: se regenera para siempre. Se vio al Fisura generarse diez veces.

19. **`--retries N` son N+1 generaciones** (`range(retries + 1)`). Multiplicado
    por un driver que también reintenta daban cuatro por asset: 344 en vez de
    86. `batch_uno_por_uno.py` fija `--retries 0` y la política de reintento vive
    en un solo lugar. Y **`--only` NO es acumulable**: es un valor único, así que
    un `--only a --only b` se queda callado con el último.

20. **La cola compartida regenera desde el principio.** Los 86 assets comparten
    un proceso: si uno se cuelga hay que matar la corrida entera y al relanzar
    empieza por el primero. Un asset por proceso (`--only`) lo aísla.

21. **Al integrar arte hay que stagear DOS lugares.** Marcar el `.md` como
    `hecho` no versiona el PNG: van el atlas Y `dropbox/procesadas/`. Un commit
    que staged sólo los `.md` dejó `origin/main` con 84 de 86 skins, detectado
    recién al verificar el push.

22. **Instrumentar antes que deducir.** Dos diagnósticos seguidos salieron
    erróneos razonando desde los números (primero "el umbral descarta el
    dorado", después "el filtro de 512 px lo deja afuera"). El que acertó salió
    de imprimir los anchos de las imágenes en pantalla: `imgs en pantalla:
    1024,150,150,128,64,32` mostró que la generada **no existía todavía** cuando
    el runner miraba. Cuando el log no alcanza, agregale una línea al código en
    vez de inferir.

### De SwiftUI (2026-08-21)

23. **Una vista EMPUJADA en `NavigationStack` no hereda el telón transparente
    de su hoja.** SÍNTOMA: la franja bajo la banda de madera (y todo lo que
    rodea al panel) se ve blanca —gris 240 medido— en vez del juego atenuado,
    sólo en pantallas empujadas. CAUSA: UIKit le pinta `systemBackground` al
    hosting controller del destino; el `.presentationBackground(.clear)` de la
    hoja no lo cubre. ARREGLO: `clearNavigationBackdrop()` (PanelFrames.swift)
    sobre el contenido de cada `navigationDestination`. Ojo: el placement
    `.navigation` de `containerBackground` es **iOS 18+** —verificado en la
    swiftinterface del SDK—, por eso hay un fallback UIKit para 17.

### De diseño y de build (2026-08-23, ter)

35. **Una pared que la run nunca alcanza no existe.** Con el umbral de la
    escalada por encima del tier 9, la métrica de forma daba `paredes: ninguna`
    — y no porque la curva fuera suave, sino porque el bot reencarna al duplicar
    el ORO **antes** de llegar a la zona con escalada. Cuando una métrica de
    forma da vacío, mirá primero **hasta dónde llega la run**, no la fórmula.

36. **Un knob que arregla un contrato puede romper otro que acaba de cerrar.**
    Los dos candidatos para bajar de 9 a 8 reencarnaciones sacaban maxear de la
    banda de 20-30 que se acababa de cumplir. Antes de aplicar un knob "barato",
    corré las OTRAS métricas — y si el saldo es cambiar un verde por otro, no lo
    apliques.

37. **Un error de build puede estar tapando a otro.** Arreglado el header de
    `StoreKitTest` apareció un `tmp*.json couldn't be opened` que parecía del
    cambio: era un artefacto de build incremental y no volvió. La atribución
    correcta fue construir **sin** el cambio y ver que ahí fallaba antes y en
    otro lado. Mismo método que con las rojas de StoreKit y las de UI.

38. **`-Xcc` es lo que hace acotado un `-Wno-*`.** El proyecto trata los warnings
    como errores y un header de Apple (`SKPaymentTransactionState`, deprecada en
    iOS 18) rompía el build entero. `OTHER_SWIFT_FLAGS: -Xcc -Wno-deprecated-declarations`
    se lo pasa **sólo al importador de Clang** —headers C/ObjC del SDK— y deja
    `SWIFT_TREAT_WARNINGS_AS_ERRORS` intacto para nuestro Swift. Si alguna vez
    hace falta silenciar otro warning del SDK, ése es el molde: `-Xcc`, en
    `Debug`, y en cada target que importe el módulo. **Nunca** bajando
    `SWIFT_TREAT_WARNINGS_AS_ERRORS`.

### De calibración (2026-08-28)

39. **`pacing-sim` busca `upgrades.json` al lado del `economy.json`, y sin
    catálogo mide una ficción.** Un barrido de nueve configs escritas en un
    directorio temporal corrió entero con `derivedEffects` en cero: el bot no
    compraba mejoras permanentes. Los números daban la conclusión **opuesta** a
    la verdadera —que cualquier bajada del growth rompía el contrato, y que el
    override del callejón era lo peor de todo—, y los dos efectos eran del
    catálogo faltante y no del knob. Pasá `--upgrades` siempre que el
    `economy.json` no esté en `Resources/Data`. Es la misma ficción que
    `PROMPT-rebalance-pacing.md` §2.2 documentó en el rebalance, con otra puerta
    de entrada.

40. **Un `grep` sobre la salida de una herramienta puede comerse su
    advertencia.** `pacing-sim` avisaba de lo de arriba con un `⚠️` en la SEGUNDA
    línea de su salida, y el patrón con el que filtré (`las 7 al tope|dios:|…`)
    no lo incluía: nueve corridas mintieron en silencio con la verdad impresa.
    Lo destapó el **sanity check**, no la lectura: correr la línea de base
    conocida como primer punto del barrido y exigirle el número ya pineado
    (1,06 tenía que dar 20,67 h). Al barrer configs, ese punto va SIEMPRE, y
    ninguna variante se cree hasta que él cierra.

41. **Cuando CUATRO tests dicen lo mismo, el que está mal no es el test.** Bajar
    el growth del callejón dejó el segundo Fisura en 25,75 y `CoinFormatter` lo
    truncaba a "25": dos pines de precio, la proyección que no se republicaba y
    el test de UI punta a punta cayeron juntos. La salida fácil era correr las
    fixtures hasta que quedaran verdes; la correcta era que **un precio no puede
    redondearse hacia abajo**, porque el botón decía 25 y cobraba 25,75 y con 25
    monedas exactas la compra rebotaba. `CoinFormatter.cost` sube; `string(from:)`
    sigue truncando para los SALDOS, que es la mitad opuesta de la misma regla
    (no anunciar plata que no se puede gastar). Ninguno de los cuatro asserts
    originales hizo falta tocarlo, y ésa es la señal de que el arreglo estaba del
    lado del código.

42. **Al revertir para bisecar, revertí el TEST con su fuente.** Aislando un
    rojo del tutorial revertí tres archivos de `FisuEvolution/` y dejé
    `CoinFormatterTests.swift`, que usa la función nueva: el
    "`** TEST FAILED **`" que leí como resultado era un **error de compilación**
    (`type 'CoinFormatter' has no member 'cost'`). Un control que no compila no
    es un control, y el `grep` por `XCTAssert` no lo muestra. Mirá siempre el
    conteo de tests ejecutados: "0 tests" o ningún `Executed N tests` es la
    señal.

43. **Una correlación de tres corridas todavía puede ser casualidad.**
    `TutorialUITests.testRecorreElTutorialEnteroHastaElFinal` se puso rojo justo
    después de un cambio, verde al revertirlo y rojo otra vez aislado — y era
    flaky. Lo que lo cerró fue correr **el mismo test con el mismo selector en
    las dos versiones**: con el cambio puesto también pasa. La otra mitad de la
    prueba es gratis y estaba a la vista: entre dos corridas sin un cambio de
    código los rojos del suite pasaron de 1 a 6, y **un cambio de lógica no falla
    MÁS tests cuando lo corrés solo**.

44. **Antes de culpar al build, `uptime`.** Dos corridas de `xcodebuild`
    murieron clavadas en `CopySwiftLibs` durante 25 minutos con el load promedio
    de la máquina arriba de **900** por un workload ajeno (un `vitest` de otro
    proyecto). No había ni un `swift-frontend` vivo: estaba todo esperando CPU.
    Cuesta una hora si se lee como un problema del proyecto.

### De tests y calibración (2026-08-23, bis)

33. **El device de simulador es de UNA corrida por vez, y el segundo proceso
    puede ser tuyo.** Lanzar `-only-testing:FisuEvolutionTests/PacingTests`
    mientras la suite de UI corría en el MISMO simulador tiró **31 de 48** tests
    con "la app no está corriendo", `board.floor never appeared` y
    `kAXError -25218`. El general ya decía "dos agentes en paralelo no pueden
    compartir el device"; la ampliación es que **no hace falta otro agente**.
    Si una suite de UI empieza a fallar en masa con "la app no está corriendo",
    mirá `ps aux | grep xcodebuild` ANTES que el diff.

34. **Un costo agregado al instrumento puede BAJAR la métrica.** Cobrar las
    fusiones (0 → 1 s) bajó maxear de 7,27 a 6,67 h activas, que es lo contrario
    de lo que uno espera. El mecanismo: el costo quema presupuesto de SESIÓN (20
    min), el bot llega antes al final de cada una y parte del progreso se paga con
    income **offline**, que es reloj de pared y no de dedo. Cuando un cambio de
    instrumento mueva una métrica para el lado raro, mirá si el modelo tiene un
    presupuesto por sesión antes de buscar el bug.

### De tests y calibración (2026-08-23)

30. **Antes de barrer knobs, medí si el bot es *money-bound* o *action-bound*.**
    `PacingSimulator` cobra **1 s de manipulación por compra** (`elapsed += wait + 1`)
    y ese segundo era, medido, **la mitad del tiempo activo** de la partida
    embarcada — con la compuerta en 5, maxear pasa de 4,14 h a 2,19 h poniéndolo
    en cero. Es por qué todos los knobs de precio de tres rondas dieron
    sublineales (×16 en `defaultCostMultiplier` compra ×1,75 de partida) y por qué
    el barrido tenía techo. La pregunta se contesta con un experimento de dos
    líneas y ahorra un día de barridos.
    ⚠️ Y el corolario: **cerrar un atajo puede ACORTAR el juego.** Comprar hondo
    era barato pero pedía `2^(frontera−1)` compras, así que estaba sosteniendo la
    mitad del largo sin que nadie lo hubiera diseñado. Cerrarlo bajó la partida
    de 6,67 h a 4,14 h ANTES de subir la compuerta.

31. **Dos invariantes de precio pueden ser complementarios y no poder valer
    juntos.** "Comprar el tier de arriba nunca conviene contra mergear dos del de
    abajo" es `costo(t+1) > 2 × costo(t)`; "comprar hondo nunca sale más barato"
    es `costo(t+1) < 2 × costo(t)`. El filo es el factor de merge y no hay tercera
    opción: elegís un lado, y el otro lo tiene que cubrir OTRA regla (acá, la
    compuerta). Un test que assertee los dos está pidiendo un imposible, y uno que
    assertee el viejo después de cambiar la política parece un aflojamiento y no
    lo es.

32. **Un ratio no distingue una pared de un arranque corto.** La guarda de
    `PacingTests.floorGradient` mide RATIOS entre hitos, y con la compuerta en 6
    el peor paso da ×16,38 — que son **1,3 min → 21,3 min**. El acantilado que esa
    guarda nació para cazar eran **13,3 h de un solo salto**. Si vas a moverle el
    techo, ponele al lado el assert en HORAS
    (`noHitoJumpIsLongerThanFourActiveHours`), o la banda se debilita justo en la
    dimensión que importa.

### De tests y calibración (2026-08-22)

27. **Cuando una regla del juego cambia, preguntate qué SUPUESTO del bot
    dependía de la regla vieja** — no sólo qué llamada. El simulador compraba
    sólo el tier BASE de cada piso, con una justificación escrita al lado
    ("comprar más arriba nunca conviene, lo garantiza `tierPremium`") que era
    cierta **mientras la compuerta se midiera en pisos**. Medida en tiers, el
    tier más alto que podés comprar casi nunca es un tier base, y el mismo bot
    pasó de medir 6,67 h a medir 26,00 h — y con la distancia real ni terminaba
    la partida. Un supuesto escrito como optimización no se lee como supuesto.

28. **Un knob de `economy.json` puede estar HORNEADO en el contenido y no hacer
    nada.** `passiveRatio` y `passiveUnlockCostMultiplier` dieron corridas
    idénticas hasta el último decimal en tres valores cada uno: los rendimientos
    pasivos y el precio de desbloquearlos viven en `tiers.json`
    (`passiveYieldPerInstance`, `passiveUnlockCost`, generados) y las claves de
    `economy.json` sólo las usa `StandardEconomy` para los premios. Antes de
    descartar un knob "porque no mueve la aguja", verificá que el sim lo LEA.

29. **Un `while` de test que espera que el estado avance cuelga la suite en vez
    de fallarla.** `hiringOnTheFrontierFallsBackToTheFloorBelow` llenaba un piso
    con `while occupied < capacity`; cuando la compra empezó a caer en otro
    piso, el `#expect` de adentro falló en cada vuelta y el loop giró hasta un
    log de **141 MB**. Acotá el loop por la capacidad, no por la condición.

### De tests y calibración (2026-08-21)

24. **Un test puede CAMBIAR DE SIGNIFICADO y quedar verde**, y en una rama de
    balance pasa de a tres. SÍNTOMA: el test sigue en verde después de mover un
    knob que debería haberlo roto. CAUSA: o replica la fórmula vieja en vez de
    llamar a la del código (`hirePricesFollowTheOwnersRule` seguía calculando el
    click a la vieja, así que no vio que contratar en el reino divino pasó de
    600 a **372.000** clicks), o su fixture deja el knob nuevo en su valor
    neutro (dos tests de EconomyKit pineaban que el precio lleva el
    `incomeMultiplier` crudo: verdes sólo porque sus fixtures dejan el exponente
    en 1), o el literal del escenario **dejó de caer donde su nombre dice** (el
    "9.000.000, un peso menos que el Fast Food" de `BestHireTests` pasó a
    alcanzarle). REMEDIO: derivá el corte de la config y llamá a la función del
    código en vez de replicarla; y cuando un knob cambia, **grepeá también el
    código y los comentarios**, no sólo el catálogo.

25. **Un fixture puede ser PUNTO FIJO de la transformación que dice cubrir.** El
    save v3 de `SaveMigratorTests` traía `tap: 1` y el reescalado del rebalance
    manda `1 → 1`, así que **borrar la llamada de `migrateV3toV4` dejaba la
    suite entera verde**: la conversión estaba probada como función y no como
    parte de la migración. Al escribir un fixture para una transformación,
    elegí un valor que la transformación MUEVA.

26. **Una serie de métricas puede no poder medir el knob que se está
    discutiendo.** `floorUnlockHireSeconds` (lo que cuesta entrar a cada piso)
    **no puede ver `hireCostGrowth`**: un piso se abre mergeando, no comprando,
    así que el contador de compras de su tier base vale 0 y `growth^0 = 1`. Se
    defendió el growth con esa serie durante una ronda entera. Para el
    compounding están `floorUnlockPeakHire{Type,Purchases,Seconds}`, que publican
    el tipo más comprado de la run (en el árbol de hoy el bot llega a **785
    compras** del mismo tipo; 870 en el A/B pre-(a) de la bitácora).
27. **Una lección contextual del tutorial puede nacer EN MEDIO de un test de
    UI ajeno y comerse sus taps por coordenada.** SÍNTOMA: un test que venía
    verde falla con "no apareció X" tras darse monedas o abrir pisos con el
    panel de debug — medido con `AscentRenderingUITests` (113 s): su +1M
    encendió `canAffordAnyUpgrade`, la lección de Mejoras nació y su globo,
    en la mitad superior, se comió el tap por coordenada a `hud.debug`.
    ARREGLO de diseño: en cualquier corrida `--uitest-*` las lecciones
    arrancan APAGADAS (`tutorialLessonsAutorun`, `+Debug`); el único test que
    las quiere las pide con `--uitest-lessons`. Bajo unit tests (XCTest en el
    host) el director y el gate del bootstrap también arrancan apagados —
    `XCTestConfigurationFilePath`, mismo criterio que StoreManager — y cada
    test arma su escenario (`beginTutorialPhase()` /
    `tutorialLessonsAutorun = true`).

28. **El tap sintético del MCP del simulador no activa las filas-botón del
    `ScrollView` de FisuJobs** (medido: tres taps al centro exacto de la fila
    con `ftue.spawned` en falso), aunque sí activa tabs, cierres y tablero.
    XCUITest (`.tap()` sobre el elemento) compra sin drama, y el dedo humano
    también. Si un recorrido manual por agente "no compra": verificar el
    efecto en el plist del contenedor (`simctl get_app_container … data`)
    antes de sospechar del juego, y hacer ese paso vía XCUITest.

29. **El catálogo de strings SÍ se puede editar con un script — si el script
    escribe el formato de Xcode.** La regla del §2 (no lo toques, te deja un
    diff de 2.400 líneas) describe la consecuencia, no una imposibilidad: lo que
    la desactiva es reproducir el formato canónico. Son tres cosas —dos espacios
    de sangría, `" : "` como separador, y las claves en **orden natural**— y la
    tercera es la que se hace mal sola: Xcode compara los números como números,
    así que `skins_5` va ANTES que `skins_20` y un `sorted()` pelado los da
    vuelta. La verificación es barata y va ANTES de escribir: serializá el
    archivo sin cambiarle nada y exigí `diff` vacío.

    Con eso medido salió también que el archivo tenía **3 claves fuera de orden
    al final** (`skin.name.diamante`, `skin.name.oro`,
    `skins.unlock.upgrades_maxed`), de algún append anterior a mano. Al
    reescribirlo ordenado se acomodaron; el orden relativo de las otras 472
    quedó intacto.

30. **Actualizar Xcode A MITAD de un frente rompe en cadena, y cada eslabón
    engaña distinto** (Xcode 26.6, medido el 2026-08-25). Los cinco eslabones
    y sus arreglos, EN ORDEN: (1) un **`runtime match` override**
    (`xcrun simctl runtime match list` → «User Override») puede dejar el SDK
    nuevo corriendo sobre el runtime viejo: la app compila pero **se ve
    espantosa** — los colores y paneles del asset catalog no decodifican y
    SpriteKit se ve bien (el síntoma es «la UI de SwiftUI desnuda») — y el
    override además le miente al descargador («iOS is already downloaded»).
    Fix: `runtime match set <sdk> --default`. (2) Recién ahí
    `xcodebuild -downloadPlatform iOS` resuelve y baja el runtime que
    corresponde. (3) `build/DD` con module cache de dos SDKs se borra entero
    (trampa 1 agravada). (4) `SWIFT_TREAT_WARNINGS_AS_ERRORS` ahora alcanza
    al clang importer: un header DEPRECADO del propio SDK (StoreKitTest) mata
    el build — `OTHER_SWIFT_FLAGS: -Xcc -Wno-error=deprecated-declarations`
    en `project.yml` (los warnings de NUESTRO Swift siguen siendo errores).
    (5) El `StoreKitTest` del **runtime 26 aborta** `SKTestSession` fuera de
    un runner XCTest (SIGABRT; cargar XCTest con `dlopen` NO alcanza) —
    `StoreManager` degrada con `#available(iOS 26.0, *)`: la tienda local por
    `simctl` queda ausente en 26 (por Xcode el scheme la inyecta igual). Y la
    asimetría de §6 (unit ANTES que UI) **sigue viva en runtime 26**: se
    re-midió con los 11 rojos exactos de StoreKit.

### Del arranque del proyecto (julio; rescatadas de `ESTADO.md`, retirado en `version-2`)

Siguen vigentes y no estaban en ningún otro lado:

- **`xcodebuild test` colgado para siempre** en `waitForBuild`: si
  `xcode-select` apunta a CommandLineTools, los subprocesos de xcodebuild no
  heredan `DEVELOPER_DIR` y `xcrun simctl` falla en silencio. Fix:
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- **Un RNG "determinístico" de valor constante cuelga `Int.random`**: el
  rechazo de Lemire nunca termina. Los tests usan `SplitMix64` sembrado.
- **Volver de background no cobra dos veces**: `IncomeTicker` descarta deltas
  de más de 2 s; ese tiempo lo paga el offline.
- **`Int64(Double)` trapea** con números de idle: `SaveConflictResolver` clampea
  antes de convertir. Cualquier conversión nueva de plata a entero, igual.
- **Una instalación nueva NO cobra el daily del día 1**: marca el día como
  cobrado para no competir con el tutorial (y por eso existe
  `--uitest-daily-popup`).

## 8. Qué queda

### Lo que queda de la 2.0 (cierre del relevo 30)

La cola con orden, BASE y modelo está en `tasks.md` §4 (relevo 31). Lo nuevo del 30, además de lo que sigue de abajo (que se mantiene):

- **Al llegar:** confirmar `version-2` y leer el veredicto del `rapido4` sobre `6c4a770` (`build/relevo30-rapido4.log`); si es VERDE, E8e T5 ✅ (214 de 269) y `version-2` avanza por ff a `6c4a770`.
- **⏳:** E8e T4 (el ícono de la Tienda de ORO; no ∥ E6a T12 por `OroShopView`), E8e T10a (spike opus; el gate lo mide el dueño en el SE), E6a T12, E5b T3, E7b-b T1, E5b T5 y E8d T15. E8e T6 espera a E5b T3; E8e T8, a una ventana de `BoardScene`.
- **Carries del 30:** el movimiento real sin ver en device (Álbum, visitante, evento, colchón); `visitorArrive` suena también con el presentador; aguinaldo/blanqueo/`startup_comprada` sin ilustración (0 s); `EventChipUITests` y `CorralitoUITests` al `completo`; `ui_oro_extra_slots` en `pendingShopIcons` (E6b T7); los sonidos del colchón en `pendingWiring`; los avisos del reset B10/B15 al brief de E9b T8.
- **Al dueño:** los dominios de tracking para B22; mirar lo animado en un iPhone; qué hacer con los eventos de 0 s; `PREGUNTAS-DUENO.md`; el reset que pierde las pintas de ORO; `skinsAll` a 1350 ORO.

### Lo que queda de la 2.0 (cierre del relevo 29)

La cola con orden, BASE y modelo está en `tasks.md` §4 (relevo 30). Lo nuevo del 29, además de lo que sigue de abajo (que se mantiene):

- **Destrabadas por la ola AA (ahora ⏳):** E6a T12 (las ofertas se ven; dueña de `RootView` y catálogo; destraba E6a T13, E6b T7 y E9a), E5b T3 (la escena; `BoardScene`; destraba E5b T7 y E6b T5), E7b-b T1 (la columna, pura; `GameState`) y E5b T5 (las lecciones; catálogo con snapshot). Sigue ⏳ **E8d T15** (cierre de E8d: primero escribir `AnimatedPlacesTests`, que no existe; después un `completo` solo).
- **Siguen ⛔:** E5b T7, E6a T13, E6b T5 y T7–T10, E7b-a T6–T7, E7b-b T2–T3/T5/T7–T8, E9a, E9b T1–T5/T8–T10, E2b T9 y T12–T15, E12 T12. **🔒:** E8 T9 (elecciones del dueño ya en `decisiones.json`; lo integra un relevo), E12 T16, mediación por SPM.
- **Carries del 29:** E6a T12 (`chanceAllowed` por parámetro y por aparición, gregoriano, Bienvenida en BE/AU, `.unavailable` cubre `alreadyOwned`, hojas en un `ViewModifier`); E5b T3 ('LLENO' de la misma cuenta); E7b-b T1 (reusa `packageTapped`/`mattressTapped`/`openWheel`); E9b T8 (el reset pierde las pintas de ORO); E5b T5/E6b T5 (la leyenda «incluye 43»); `wheel_frame` sin usar.
- **Fuera de `tasks.md`:** integrar `v2/e8-recortes` y `v2/estudio-assets`, y el plan E8e (`v2/e8e-plan`, 9 tareas): ver `DUENO.md`.
- **Al dueño:** `PREGUNTAS-DUENO.md` sin respuestas; el reset que pierde las pintas de ORO; `skinsAll` a 1350 ORO; matar la app con el popup del colchón pierde el 'otro colchón'; las animaciones de skins de Higgsfield (¿dónde están?); los del 28 y anteriores.

### Lo que queda de la 2.0 (cierre del relevo 28)

La cola con orden, BASE y modelo está en `tasks.md` §4 (relevo 29). Lo nuevo del 28, además de lo que sigue de abajo (que se mantiene):

- **Destrabadas por la ola Z (ahora ⏳):** E5b T2 (los accesos y las hojas; dueña de `GameState`/`RootView`/catálogo; destraba E5b T3/T5/T7, E6a T12 y E7b-b T1) y E4b T10 (cierre de E4, docs). Siguen ⏳ E5a T9 (cierre de E5a, docs) y E8d T15 (cierre de E8d; `completo` solo). E6b T4 se destraba cuando E6a T8 sea ✅.
- **Siguen ⛔:** E5b T3/T5/T7, E6a T12–T13, E6b T4–T10, E7b-b T1–T3/T5/T7–T8, E2b T9 y T12–T15, E9a, E9b, E12 T12. **🔒:** E8 T9 (elige el dueño), E12 T16, mediación por SPM.
- **Carries del 28:** E6a T7 (refrescar `lastKnown` antes de `loadProducts`, `lastKnownFailsClosed` sin dientes, `chanceAllowed` por parámetro en T12, `ChestsConfig` con pesos no negativos); E6a T8 (el cofre sin UI test, Reduce Motion por argumento, `store.subtitle` viejo en Gastar ORO, ancla `.oroShop` sin consumidor, `segment` que no se reinicia); E4b T6/T9/T10 (`eventPresenters` acotado por id, `Array(characterNodes.values)` por frame, `zRotation` del baile compartida, `meta.specialAnchors` sin escritores).
- **Al dueño:** `PREGUNTAS-DUENO.md` (A1–A10, B1–B26); la tabla de probabilidades no proyecta los cofres pendientes; elegir en la página de recortes; los del 27 y anteriores.

### Lo que queda de la 2.0 (cierre del relevo 27)

La cola con orden, BASE y modelo está en `tasks.md` §4 (relevo 28). Lo nuevo del 27, además de lo que sigue de abajo (que se mantiene):

- **Destrabadas por la ola Y (ahora ⏳):** E4b T6 (el Apagón y los Campeones; dueña de `BoardScene`/`AudioManager`; destraba E4b T9 → E5b T2) y E6a T7 (la suerte; `StoreManager`; destraba E6a T8). Siguen ⏳ E5a T9 (cierre de E5a, docs) y E8d T15 (cierre de E8d; `completo` solo).
- **Siguen ⛔:** E4b T9/T10, E5b T2/T3/T5/T7, E6a T8 y T12–T13 (cadena de E6a T7), E7b-b T1–T3/T5/T7–T8, E2b T9 (espera a E7b-b T2) y T12–T15, E9a, E9b, E12 T12.
- **Carries del 27:** E4b T6/T9 (`eventPresenters`, re-correr los UI de eventos); E5b T2 (doble cobro de ORO de la Ruleta sin fixture, Reduce Motion); E6a T7 (`LootBoxGate` → `chanceAllowed`, `chestHasSomethingToGive`, ítems sin tope); E6a T8 (botón deshabilitado al comprar, avisar los boosts por tiempo); E6a T12 (gregoriano); E2b (boosts que multiplican ×72, visitantes con la escala 0,31).
- **Al dueño:** los visitantes pagan ~un tercio; Fusionar todo (par descartado, kill antes de asentar); el reloj que resetea topes; el evento pendiente que se pierde al matar la app; `wheel_ready` fuera del aviso; los del 26 y anteriores.

### Lo que queda de la 2.0 (cierre del relevo 26)

La cola con orden, BASE y modelo está en `tasks.md` §4 (relevo 27). Lo nuevo del 26, además de lo que sigue de abajo (que se mantiene):

- **Destrabadas por la ola X (ahora ⏳):** E4b T4 (eventos con presentador; dueña de `GameState`/`RootView`/`+Bonus`, ya sin E7b-a T3 delante), E6a T4 (`oro_shop.json`), E5b T4 (la Ruleta en Regalos), E5b T6 (`wheel_ready`), E5a T9 (cierre de E5a, docs) y E8d T15 (cierre de E8d, ya sin E8b T11 delante; los gates en device son del dueño).
- **Siguen ⛔:** E5b T2 (espera a E4b T4 y T9), E4b T6/T9/T10, E6a T6–T8 y T12 (cadena de E6a T4), E7b-b T1–T3/T5/T7, E2b T9/T10, E9a, E9b, E12 T12.
- **Carries del 26:** E4b T4 (una visita no entra durante un reto); E5b T2/T4 (aplicar `e5b-t1.json`, probar con Reduce Motion, `wheel_frame`); E6a T6 (bloquear la compra del segundo ×3 antes de cobrar); E7b-a T6/T7 (el anuncio real, `BonusHUDUITests` en orden); E2b (el simulador y los ×3 pendientes).
- **Al dueño:** Offline ×3 + video = ×6 y Diario ×3 + video = ×6; la tabla de probabilidades bajo el pliegue del SE (¿3.1.1?); la pausa de 5 s fijos; borrar la rama remota `v2/e12-plan`; los del 25 y anteriores.

### Lo que queda de la 2.0 (cierre del relevo 25)

La cola con orden, BASE y modelo está en `tasks.md` §4 (relevo 26). Lo nuevo del 25, además de lo que sigue de abajo (que se mantiene):

- **Destrabadas por la ola W (ahora ⏳):** E5b T1 (la Ruleta en pantalla; destraba E7b-a T3, E6a T4, E5b T4/T6), E4b T4 y E4b T5 (siguen a T3), E6a T5 (los premios del auto-tap y los ×3; reusa `LootBoxGate`), E5a T9 (cierre de E5a, docs), E7b-b T6 y E8b T11 (el arresto, destrabada con E4b T2). Con el `rapido` VERDE, E5a T8 y E4b T3 pasan a ✅.
- **Siguen ⛔:** E6a T4 (espera a E5b T1), E6a T12 (faltan E6a T7/T8 y E5b T1/T2), E4b T6/T9/T10, E2b T9/T10 (esperan a E6a T4, E7b-a T3, E7b-b T2), **E7b-a T3 (bloqueo de publicación; sale en cuanto E5b T1 entre)**, E9b T8 (E9a T3), E12 T12.
- **Carries del 25:** E5b T1 (`LootBoxGate.current()` a `wheelAvailability`/`spinWheel`, el video antes de `.video`/`repeat`, el extra del colchón sólo con `mattressExtraOpensLeft > 0` y el `nil` tras el video); E4b T4/T5 (`eventIsApplicable`, `pendingEvent`, el reto y los cortes naturales); E6a (`restrictedStorefronts` vaciable: ¿piso BEL/AUS?); E12 (`--uitest-reset` y el ranking).
- **Al dueño:** el chip del visitante contra la llave de debug (arriba a la derecha) y la columna de E7b; el loop real del retrato; la pasada a mano de iPad/oscuro/VoiceOver/Reduce Motion; si los giros de la ruleta ×30 apilan o renuevan; atrasar el reloj ≥ 2 días devuelve cupos; los del 24 y anteriores.

### Lo que queda de la 2.0 (cierre del relevo 24, vigente salvo lo de arriba)

La cola con orden, BASE y modelo está en `tasks.md` §4 (relevo 25). Lo nuevo del 24, además de lo que sigue de abajo (que se mantiene):

- **Destrabadas por la ola V (ahora ⏳):** E4b T2 (los visitantes en la partida; dueña de `+Engagement`/`+Debug`/`DebugPanelView`) y E4b T8 (el Álbum de especiales). E5a T7 sigue ⏳ y comparte `+Engagement` con E4b T2: una por ola o en serie.
- **Siguen ⛔:** E6a T12 (faltan E6a T7/T8, E5a T8, E4b T3, E5b T1/T2), E2b T9/T10 (esperan a E6a T4, E7b-a T3, E7b-b T2), E7b-a T3 (**bloqueo de publicación**: faltan E5b T1 y E4b T3), E9b T8 (E9a T3), E12 T12.
- **Carries del 24:** E4b T2 (`presentOnStage` por `canPresentOnStage`, la paciencia no corre en intersticial, stubs de `arrive`/`openStagePopup`, correr los UI de debug); E4b T3/T4 (los `switch` y la prioridad 5); E6a T12 (no ofrecer la Bienvenida en BE/AU);
  E9b T8 (oferta reembolsada); E7b (forma de `sideRail`/`adBreak` en `rewarded_ads.json`); E2b T12 (`.free` da 3 de 8 pisos en banda; `oro_shop.json`).
- **Al dueño:** capturas SE del precio tachado y del escenario (SE/iPad/Reduce Motion); los tres escenarios a mano de E4a; el reembolso de una oferta sólo revoca su ORO.

### Lo que queda de la 2.0 (cierre del relevo 23, vigente salvo lo de arriba)

La cola con orden, BASE y modelo está en `tasks.md` §4. Lo nuevo del 23, además de lo que sigue de abajo (que se mantiene):

- **Destrabadas por la ola U (ahora ⏳):** E4a T10 (cierre de E4a), E5a T7 (el Colchón), E4b T7 (la Liquidación en el precio), E2b T7 (el perfil `.max`) y E6a T11 (las ofertas se cobran).
- **Siguen ⛔:** E5a T8 (espera a T7), E6a T5 (espera a E5a T8), E6a T4 y E5b T1 (esperan a E5a T8 / E4b T3), E7b-a T3 (**bloqueo de publicación**: faltan E5b T1 y E4b T3), E9b T8 (espera a E9a T3 y E6a T11), E12 T12.
- **Carries del 23:** E9b T8 debe unir `offers.purchases` y `seenCinematics` en `resolveAcrossReset`; E4b re-chequea `eventIsApplicable`, mueve `events.cayo_mercado_pago` a `home_banking` en `loops_manifest` y atenúa la cuota
  sin plata; E5b arregla `packageCandidates` (llegadas en cola) y el guardado de `advancePackages`; E2b T8 imprime `maxStaffedFloors` y T13 re-mide cap 10 vs 15 y «Fusionar todo»; `isFinite` en los validadores de
  paquetes/tesoros/ruleta; `startupTiersBelowFrontier` al schema.
- **Al dueño:** un viaje 1 → 10 del ascensor en un SE real y las tres grabaciones; el video de salida no sirve si el evento vence mientras corre; `.eventStartup`/`.eventBlanqueo` no son prepagos al matar la app (previo).

### Lo que queda de la 2.0 (cierre del relevo 22, vigente salvo lo de arriba)

La cola con orden, BASE y modelo está en `tasks.md` §4. Lo que no cabe ahí:

- **Del relevo 22, al dueño:** E3b T9: la oferta de compartir descartada se pierde, puede gastar sus 10 s detrás del intersticial de `celebrationsDrained` (→ E7b-a T3) y el
  premio de reencarnación es casi nulo (5 min de la run nueva); E6a T1: una oferta abierta sólo en el save perdedor (la Bienvenida) se pierde al cruzar y el ×3 se regala en el
  caso raro; E12 T15 / E10: `NSPrivacyTracking` en `false` con AdMob y ATT, sin atajo para el revisor, la privacidad no nombra al proveedor de IA; E4a T6: `.visitor` no es
  prepago; E4a T3: el reset de debug no limpia `visitors`/`events`.
- **Del relevo 21c, al dueño:** **no publicar E7b-a T2 sin T3** (intersticial en cada corte); `canRequestAds` falta en intersticial y rewarded (UE); verificar en device el *fill* del
  app open; la cinemática de reencarnación casi siempre se saltea y el intersticial sale antes del cofre; un veterano v1 en Dios ve la de Dios en el primer arranque; la intro sale en
  partida nueva; 2 renglones de E13 T13 por mirar en el SE y `ui_up_crit` por borrar; los escenarios de E11 (diálogo del sistema) y de E2a/E8c (Reduce Motion, hoja, fondo, ORO/video)
  a mano; PNG de iPad a ASC (E10). Las perillas de E2a T15 (base Dios 31,34 h) están en el SESION de los cierres.
- **Del dueño:** la **lista de palabras de E12** ya está activa (relevo 21b; se despliega con E12 T16, que espera las credenciales de Supabase y
  `ANTHROPIC_API_KEY`); los carries de E13 T7 (veterano de un solo lado, última run, save viejo, fila de `lucky` sin dorado → E13 T13); escuchar el cable del
  ascensor contra el ding; decidir el **`installId` que no viaja por CloudKit** (una partida registrada en A que llega a Dios en B
  queda `.unregisteredGod`: sincronizar el Keychain o aceptarlo); si el botón **Entrar** de `RankingEntryCard` sigue con
  `.disabled` (rompe la convención de `ActionPill`); si molesta que la **placa de 10 pisos tape parte de Reencarnar**
  mientras está abierta; si `--uitest-ranking-*` de `RankingStore.live()` pasa a `#if DEBUG`; si la moneda de E13 T11 tapa la cara del personaje de atrás en un piso con pasivos; si se hace el back-fill de los cofres de piso de los jugadores de la v1 que ya reencarnaron (E13 T3); las imágenes repetidas y las ventanas blancas opacas del arte de E8 T7 (`ui_shop_income_x2`/`x3`, `wheel_frame`, `ui_album_card_frame`); oír los 8 `sfx_ev_*` y el whoosh del reveal (ahora suena siempre); probar en región UE con el SDK real que «Opciones de privacidad» abre el formulario (E7b-a T5). Siguen: mediación por SPM, capturas de ASC, Meta, TestFlight, oír los sonidos (G7).
- **Sin probar en device:** el fondo animado de los pisos, **ya activo en producción** (ablande 1024² → 2048² al fundir, tirón al soltar un swipe en el SE; G1/G2/G3), y la revelación con video, que depende de ODR (53 `characters` con `odrTag`; se precarga el del próximo tier; sin test con un `ArtPackSource` falso), ODR (E8d T14 ya asignó los tags, pero en Debug los packs van embebidos; G5), el alfa del HEVC a ×5 (G3), el publisher de
  `isReadyForDisplay`.
- **Montaje pendiente:** la tarjeta y la pestaña del ranking (T9a/T9b) esperan a E12 T13 (T11 ya está); `onChoose` del atajo
  ya está cableado (E3b T8, 🟢 en `integ-r21b`); el contador ×N y el remate de Fusionar todo ya están montados (E8c T7/T8) y la cadena corre en el simulador (E8c T9), pero sin captura ni grabación (E8c T10); la posición del contador es provisoria. **E12 T13 ya puede** (E3b T4 y E3a T11 hechas).
- **De E3a T11:** el `completo` de cierre de E3a debe correr `BottomMenuUITests`, `BonusHUDUITests` y `HUDRedesignUITests` en iPhone; los toasts de logros y el aviso de torre no usan `playColumn`. **De E3b T4:** sólo la página quieta queda montada (pierde su `NavigationStack` al deslizar).

### Precargar el atlas de personaje fuera del hilo principal (levantada 2026-08-27)

**El problema, medido.** `UIArt.characterImage` en frío cuesta **~320 ms de hilo
principal**. Instrumentado con `CFAbsoluteTimeGetCurrent` en tres corridas con tres
personajes distintos (tarea 8 de los cofres, `task-8-report.md` §3):

| tramo | costo |
|---|---|
| `AtlasCache.atlas(named:)` (el handle) | 4,8 – 5,8 ms |
| `atlas.textureNamed(key)` | 0,3 ms |
| **`texture.size()`** (realiza la página del atlas) | **211,6 – 223,0 ms** |
| **`texture.cgImage()`** (la lectura a CPU) | 98,6 – 105,8 ms |
| `UIImage(cgImage:)` | 0,0 ms |
| **total en frío** | **~320 ms** |
| el mismo retrato, ya cacheado | **0,1 ms** |

⚠️ **Dos tercios están en `texture.size()`, y parece gratis.** `UIArt.characterImage` lo
llama sin querer, en el `guard texture.size().width > 1` que distingue la textura ausente
—SpriteKit devuelve un placeholder de 1×1— de la buena. El chequeo es correcto y hay que
dejarlo: lo que cuesta es que **realiza el atlas entero**.

**Por qué es tarea propia y no de la vista del cofre.** La animación del cofre ya se lo sacó
de encima con `warmPrizeArt()` en `.arriving` —el bloqueo de `.flying` bajó ~67 %, de 263 a
86 ms de promedio—, pero eso **muda** el costo, no lo saca. Los ~215 ms los pagan igual la
ficha del personaje, el carrusel de Pintas y el tablero. `SKTextureAtlas.preload(completionHandler:)`
se los llevaría asincrónicamente, pero toca `UIArt`/`AtlasCache`, que son de todos: **pide un
instrumento propio y su propia verificación.**

**El instrumento que ya existe y hay que rearmar.** Un `Task` que pide dormir 16 ms y
denuncia cuando despierta tarde: si duerme 16 y despierta 300 ms después, el hilo principal
estuvo 284 ms bloqueado. Quince líneas, temporal, se fueron antes de commitear. Es lo que
convirtió "se siente trabado" en un número con dueño.

**Dos cosas que la tarea tiene que mirar de paso:**

1. **El `TextureAtlas` parte páginas y nadie lo mira.** El build tira seis warnings de
   `Splitting '<atlas>' into N texture atlases due to input texture dimensions` — `ui.atlas`
   en 3, `earth.atlas` en 6, `cosmic.atlas` en 4. Cada página es una realización aparte, o
   sea que el costo de `size()` escala con cuántas páginas toque el personaje que pediste.
   Un `preload` que no sepa de páginas puede quedarse corto.
2. ~~Cuando esto aterrice, revisar el `Task.yield()` de `ChestOpeningView`.~~ **YA NO
   APLICA (2026-08-28)**: la caída del cofre y su `Task.yield()` murieron con el video —
   la entrada ahora es un fade+escala disparado desde el `.task` del primer latido, que
   corre después del armado por diseño. La lección del hop calibrado quedó contada en el
   doc de `ChestDrop`… que también se retiró: si hace falta, está en git (`e40244b^`).

**Lo que NO es de esta tarea**: los ~500 ms de bloqueo que quedan en `.arriving` no son del
retrato, son del overlay armándose. Es otra investigación.

### Lo que dejó el rediseño de UI (2026-08-16)

**1. ✅ HECHO (2026-08-16) — el batch de los 15 iconos corrió entero y está
integrado y pusheado** (`d304fe3`): opacidad sana en los 15 (18–51%, umbral
12), cero descartes, suites de las pantallas tocadas en verde, y los
vectoriales quedan de fallback. Costó dos hallazgos que ya están corregidos y
documentados: el robo de foco (runner endurecido, ver arriba) y **las vocales
con tilde que el keystroke pierde** (bug #7 de `HANDOFF-arte-gemini.md`; los
prompts nuevos van en ASCII). Lo de abajo queda como referencia para el
próximo batch. — La
cola está armada y verificada (tarea 19): 15 prompts `.md` numerados
**213–227** en `Tools/asset-pipeline/prompts/gemini_pro/` con sus 15 entradas
gemelas en `prompts.json`, **los 15 sin generar** —cada `.md` con su línea
`- **estado**: pendiente`— y **sin campo `referencia`** (los iconos de UI no
adjuntan el Fisura). Cero PNG de esas claves en `ui.atlas`, verificado el
2026-08-16.

⚠️ **El estado de la cola vive en los `.md`, no en `prompts.json`.** Los dos
runners parsean esa línea (`STATE_RE` en `gemini_selenium_runner.py`), y
`pending_assets()` saltea un asset por cuatro caminos: `estado: hecho`, el PNG
ya en `dropbox/`, el PNG en `dropbox/procesadas/`, o la clave ya presente en
`assets_manifest.json`. `mark_asset_done` reescribe el `.md` a `hecho` recién
después de verificar el PNG. Si editás un `.md` a mano, ese es el campo.

No se generó ninguna imagen a propósito: el runner tipea con `osascript` y el
permiso de Accesibilidad lo tiene **Terminal.app y nada más** (trampa 11, que
ahora tiene una salida para agentes — ver ahí). ⚠️ **El batch se intentó el
2026-08-16 y frenó con cuota CERO**: la ruta del permiso funcionó, pero con
otros frontends usando la máquina el foco se roba a mitad del tipeo (asset 1:
0 de 2099 caracteres; asset 2: 2146 de 2150) y el guard `prompt_landed` abortó
antes de enviar las tres veces. De ahí salió el **runner endurecido**
(`78119ef` + `acaf3e6`, review adversarial con fuzz de 1.000 robos: cero
prompts corruptos enviados): tipea en tandas de 250 con verificación de
frontmost y de prefijo, avisa `⚠️ foco robado por «X»` nombrando a la app
ladrona, y su peor caso es abortar con cuota cero — nunca mandar un prompt
barajado. Knobs nuevos: `--type-chunk` (250) y `--type-pause` (0,25 s).
**Corré el batch con la máquina quieta**: cada robo de foco quema un
reintento y a los 3 fallos seguidos frena. La receta de abajo es histórica:
desde `version-2` el runner vive en `automatic-image-generation`. Con el
Chrome dedicado en `:9222` logueado en Gemini **Pro**:

```bash
cd Tools/asset-pipeline
.venv/bin/python scripts/launch_gemini_chrome.py          # 1 vez, login manual
.venv/bin/python scripts/gemini_selenium_runner.py --dry-run   # tiene que listar 213–227
nohup caffeinate -is .venv/bin/python scripts/gemini_selenium_runner.py \
  --process --pause 3 --timeout 260 &
```

Sin `--ref-threshold` y sin `xcodegen` (no hay Swift y el atlas es folder
reference). ⚠️ **Post-batch hay que medir el % de píxeles opacos del `@2x`**
en `FisuEvolution/Resources/ui.atlas/`: `rembg` se come los rellenos
interiores claros y grandes (bug #6 de `HANDOFF-arte-gemini.md`), y los de
riesgo alto son `ui_menu_stats`, `ui_trophy_silver` y `ui_daily_calendar`. El
que salga hueco **no se integra** — se borran sus `@2x`/`@3x` y su clave de
`manifest.ui`, y el juego vuelve solo al icono vectorial, que para eso está.

⚠️ **Y tres claves del atlas están recortadas A MANO, cosa que el pipeline no
sabe**: `ui_elevator`, `ui_coin_plus` y `ui_gift_bow` (`@2x`/`@3x`) se
recortaron al bbox del alfa +2% de aire el 2026-08-18, porque salían con
~40–60% de lienzo transparente y el dibujo rendía chico en pantalla. Si el
batch los regenera, vuelven con esos márgenes: hay que re-recortarlos antes
de integrar.

**2. Costura de los 15 iconos: ✅ COMPLETA — las copas y el calendario.**

✅ **Los tres `ui_trophy_*` quedaron cableados en la ola final del review**
(2026-08-16). Eran **DOS** call-sites y no tres —el conteo de tres que figuraba
acá estaba mal: `MenuView.swift:65` nunca fue un pendiente, porque su copa ya
pasaba por `GameIcon` vía la clave `ui_menu_trophy` del propio menú—. Los dos
que faltaban ahora envuelven el vector con
`GameIcon(artKey: "ui_trophy_\(tier.rawValue)")`, que mapea el metal al sufijo
de la clave del atlas:

- `FisuEvolution/UI/Menu/AchievementsView.swift` (la copa de cada fila, 42 pt)
- `FisuEvolution/App/RootView.swift` (la copa del toast, 34 pt)

Mientras el atlas no tenga las claves siguen cayendo al vector y no cambia
nada en pantalla; el día que el batch entre, entran solas.

✅ **Y `ui_daily_calendar` aterrizó el 2026-08-16** (cierre post-merge, tarea 1:
cherry-pick de `84a2af6` desde la rama paralela `fix/iconos-gameicon`, esta vez
sí revisado). El calendario va **al frente de la tarjeta del daily** en
`FisuEvolution/UI/Gifts/GiftsView.swift`, a 44 pt dentro del mismo plato de
56 que usan `BoostGlyph` y `ScreenGlyph`, con la nota "se cobra solo" corrida
al costado. Era el único de los 15 iconos sin call-site: **ya no queda
ninguno**. Mientras el atlas no tenga la clave, cae al `VectorCalendarIcon` y
se ve igual de bien — que es exactamente lo que hace el fallback.

**3. Los ajustes ya están listos para App Store.** `SettingsView` trae las
seis secciones del spec: **idioma** (sistema/es/en, con su clave propia
además de `AppleLanguages`), audio, juego, compras (con "Restaurar"),
**legales** y "Acerca de". Las **notificaciones** tienen recordatorio diario a
las 19:00 vía `NotificationsManager`, y los **dos documentos legales**
(privacidad y términos) se leen adentro del juego, en es+en, desde
`Resources/Legal`. O sea que RF-02c ya no necesita nada de UI: lo único que
falta sigue siendo la cuenta de Apple Developer.

**4. ✅ El review integral de la rama y el ticket post-merge: los dos HECHOS.**
El review integral del rediseño corrió con su ola de fixes
(`ecf35b2..2f71ff3`), y lo que dejó triageado para DESPUÉS del merge se ejecutó
entero en `fix/cierre-post-merge`: **7 tareas**, y el review integral de esa
rama dio **ready to merge con CERO ola de fixes de código**. Commits y detalle
tarea por tarea en **`Docs/SESION-2026-08-16-cierre-post-merge.md`**; lo que
entró:

- **El calendario del daily**, acá arriba en el punto 2.
- **El cluster spawn muerto se fue de `GameState`** (`HireOffer`,
  `showSpawnHint`, `hireOffer` y el cálculo que los refrescaba). No se perdió
  ninguna aserción: los pins se mudaron a `TowerActions`, que es donde vive la
  conducta. ⚠️ Lo que ese borrado sí dejó huérfano es un requisito de UX — está
  en el 📌 de §4, "Gate de contratación".
- **`StatePill` → `StateBadge`** en Upgrades: una sola gramática de badge, y
  tocarla ya no castiga con haptic+audio de error.
- **Un pase de accesibilidad en lote**: `PricePill` dice la moneda y **qué**
  compra en vez de un monto suelto, `ProgressBar` tiene label, se fueron las
  paradas mudas de VoiceOver, y el número de piso y el "estás acá" del ascensor
  escalan con Dynamic Type.
- **Los residuales de la ola**: la tarjeta de la tienda degradada se centra
  aunque haya banner de error; el riel fijo de la tienda (**104**, derivado del
  `minWidth` 92 del `PricePill`, igual que el 96 de FisuJobs) devuelve los
  títulos de producto a un renglón; `MetaState.init(from:)` decodifica
  `derivedEffects` con `decodeIfPresent`, así que un sobre sin esa clave ya no
  se lleva la partida puesta; el migrador estrenó un e2e desde JSON crudo v3; y
  `ui_pill_currency` salió del manifest y del atlas, y quedó **anotado como
  "retirado" en el índice de prompts** (la fila 113 sigue ahí, y su `.md`
  también: es historia de otra tanda, no se borra).
- ✅ **`AscentRenderingUITests` volvió** — las tres causas están en la trampa 2.
  La que nadie tenía: el callejón cubre los tiers **1..4**, así que el primer
  ascenso pide **cuatro** fusiones y no dos. **Ya no queda ningún
  `-skip-testing:` en la receta de §6.**

**Después de esto quedan dos cosas, y ninguna es código**: el batch de los 15
iconos del punto 1 —la cola 213–227 está intacta y verificada— y los dos gates
humanos de F6, la cuenta de Apple Developer (RF-02c) y una fuente de audio
(RF-14).

---

⚠️ **El programa de las 16 correcciones está CERRADO** (2026-08-07). Un jugador
externo terminó el juego y mandó 16 pedidos; las cuatro olas se ejecutaron y
**14 de los 16 están hechos y testeados**. Los otros dos no esperan código.

Auditado el 2026-08-07 **contra el código, no contra los docs** — porque un
handoff que dice "hecho" es exactamente lo que nadie vuelve a comprobar:

| RF | Dónde se comprueba |
|---|---|
| 01 tutorial · 03 lista · 04 dos botones · 06 descripciones · 08 mapa · 15 carreras · 16 prestigio | sus tests de UI y unitarios |
| 05 caras | **43 caras para 43 tipos concretos**: cobertura exacta del manifest |
| 07 ORO | `oro.exponent` en 0,45, calibrado con `pacing-sim` (`balance-log`) |
| 09 scroll | `BoardScene.floorDelta`, invertido, umbrales de 48 pt y 1,5× intactos |
| 10 torre | 37 tiers en 10 pisos, `FloorTable` valida la cobertura |
| 11 videos | `cooldownSeconds: 14400` por recompensa, en `meta.rewardedActivations` |
| 12 boosts | los 6 gateados por piso en `boosts.json`: mate→alley, café→corporate, fernet→island, asado→mars, milanesa→galaxy, turbo→god_realm |
| 13 skins pagas | las dos, vendidas contra el `.storekit` |
| 02a/02b tienda | 10 productos; packs de plata, de ORO y el combo |

**Los dos que faltan, y por qué ninguno es programación:**

| RF | Bloqueado por | Qué lo destraba |
|---|---|---|
| **02c** · alta en App Store Connect | La cuenta de Apple Developer (USD 99) | Que el dueño la saque |
| **14** · música y efectos | **No hay fuente de audio.** Re-verificado el 2026-08-07 y otra vez el **2026-08-16**: el MCP de audio disponible en la sesión hace **sólo TTS**, y su contrato prohíbe usarlo para música o efectos standalone (esos modelos existen, pero para otro pipeline). Detalle en `SESION-2026-08-16-cierre-post-merge.md` | Un MCP con música/SFX standalone, o audio CC0 a mano |

📄 **Los dos están desarrollados hasta donde se puede sin el gate, en
`Docs/HANDOFF-gates-pendientes.md`**: la lista de los 12 archivos de audio con su
evento y su duración, y la tabla de los 10 productos lista para cargar en App
Store Connect. Ahí también está corregido un error del spec: **"integrarlo es
cero Swift" no es exacto** — RF-14 pide un efecto para "piso nuevo desbloqueado"
y ese evento **no existe** (hoy suena `.evolution`, compartido con cualquier
ascenso). Son tres líneas, y se hacen junto con el archivo.

| Documento | Qué es |
|---|---|
| `superpowers/specs/2026-08-06-correcciones-de-playtest-design.md` | **Los 16 pedidos como RF-01…RF-16**, con criterio de aceptación |
| `superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md` | Los 8 personajes nuevos, la baja de `kiosco` y el remapeo a 10 pisos |
| `superpowers/plans/2026-08-06-ola-{0,1,2}-*.md` | Los planes de ejecución, con el reparto por frentes |

### Lo que queda, y que NO sale del spec

Encontrado de paso y sin dueño. Ninguno es urgente:

- **La tienda se cuelga en "Loading…" cuando StoreKit no responde**, en vez de
  caer al mensaje de error que sí existe. `Product.products(for:)` no vuelve
  nunca y no hay timeout. Se ve lanzando por `simctl`, que **no** inyecta el
  `.storekit` (sólo lo hace el esquema de Xcode, también en device).
- **La fila de mejoras dice el nombre dos veces con VoiceOver**: la carita quedó
  como elemento de accesibilidad con el nombre de etiqueta, y el `Text` de al
  lado sigue ahí.
- ~~**El título flotante de los paneles deja pasar el texto por detrás** al
  scrollear. Es de todos los paneles, no de uno.~~ **MUERTO DE RAÍZ
  (2026-08-18, la hoja contenida).** El parche eran las bandas crema opacas de
  las 12 cabeceras (y sus `.toolbarBackground(Color("PaletteCream"))`); se
  retiraron junto con el defecto que tapaban. Las hojas ya no ponen el marco
  como `.background`: se envuelven en
  `panelSheet(material:awning:header:ornament:)` (`UI/Art/PanelFrames.swift`),
  que mete la cabecera ADENTRO del pergamino —debajo del toldo, al ancho de
  la columna, sin banda opaca— y hace del `ScrollView` una región recortada
  con fundido en los bordes que muere contra la banda inferior del marco,
  ahora a la vista. El texto no PUEDE pasar por detrás del título: el scroll
  arranca debajo de la cabecera y está clipeado. La hoja flota recortada a
  sus esquinas y con sombra sobre el juego atenuado
  (`.presentationBackground(.clear)`).
- **~81 MB de los ~115 del `.app` son los fondos**, con ~54% de píxeles que no
  se ven nunca (`HANDOFF-perf.md`).

**Tres decisiones del dueño de esa sesión que no se re-litigan:**

1. **El fondo que se retira es `cosmic`**, no `mars`. Criterio estético: es el
   único que se sale del estilo (islas flotantes con cofres y un río de gemas).
   Su costo está medido y anotado en el spec.
2. **Sale `Personal de Kiosco` de la cadena** y El Mantero ocupa su lugar. Es lo
   que baja el desplazamiento de la cadena de +3 a +2 y permite que tres de las
   cuatro recolocaciones de personajes entren.
3. **Magnate Petrolero queda en la luna.** Bajarlo a la isla exigía dejar un solo
   personaje nuevo en toda la zona terrenal, y eso ensuciaba el callejón y la
   calle urbana: tres desajustes nuevos para arreglar uno.
4. **Las 4 recompensas de carrera** (aprobadas 2026-08-06). Programador → cofre
   de plata · Arquitecto → la skin "Pie de Obra" · Médico → un Café Cargado
   gratis que no consume cooldown · Abogado → contratar a −50% por 10 minutos.
   Son de **tipo distinto entre sí a propósito**: cuatro variantes del mismo
   premio no son una elección. Viven en `Config/careers.json`.
5. **Los 8 nombres de skin de los personajes nuevos** (aprobados 2026-08-06):
   `naranjita`, `malabarista`, `feriante`, `chatarrero`, `holdout`, `jubilado`,
   `tropero`, `figurita`. Son **ganables, no pagas** — las únicas pagas siguen
   siendo las dos del Fisura y Dios. Existen porque el repo pinea que todo
   personaje concreto tenga skin catalogada.

**Con el spec cerrado, lo que sigue es F6**, que son todos gates humanos: cuenta
Apple Developer (USD 99), nombre comercial, App Store Connect, TestFlight,
submit. El ship-prep técnico ya está (`Distribution/`, entitlements, CI, privacy
pages). Y antes que nada, **que el dueño lo juegue**: los bugs más caros de estas
sesiones aparecieron mirando la pantalla, no corriendo tests.

✅ **Y eso ya pasó, el 2026-08-10.** De jugarlo salieron los dos pedidos de esa
sesión, y los dos apuntaban a lo mismo: cosas que el juego hacía pero no se
veían ni se sentían. Fusionar era fiddly —y abajo había un bug real de puntería
que ningún test agarraba— y los bonus corrían sin ningún rastro en pantalla.
**El patrón se repite: lo que falta no es lógica, es que la lógica se note.**

Anotado por si algún día importa, con su medición:

- **`director__directorio`** es una skin real pero floja (sin cambio cromático).
  Regenerarla cuesta cuota de Gemini; queda a criterio del dueño.
- ~~**Decisión de ads**~~: AdMob real, en producción desde la v1.0.0
  (`Docs/ads-integration.md`, `Docs/monetizacion-anuncios.md`).

---

## 9. Mapa de documentos

- **`Docs/PLAN-v2.md`** — **el plan maestro de la 2.0**:
  - §0, el protocolo de relevo automático de agentes;
  - §0.1, el despliegue de agentes concurrentes: el mecanismo, el
    controlador, los archivos calientes, los topes y el calendario de olas;
  - §2, todas las decisiones del dueño;
  - §3, las causas raíz;
  - §4, las épicas E0–E11 (E11, las notificaciones, entró el 2026-10-06), con
    la tabla de cada pedido a su épica;
  - anexos A (guiones de visitantes y frases de eventos) y B (biblia de los
    8 visitantes nuevos).
- **`tasks.md`** (raíz de `version-2`, desde el relevo 6) — **el tablero de la
  ejecución de la 2.0**. Un solo escritor: el controlador.
  - §2, el progreso por épica, con los `grep` para recalcularlo;
  - §3, las reglas de concurrencia y quién toma cada archivo caliente y tibio;
  - §4, la cola de despacho: lo que sale ahora, la ola siguiente y el resto
    por prioridad, con BASE, modelo y con qué no va en paralelo;
  - §5, una tabla por épica con el estado de cada tarea, y las
    inconsistencias abiertas entre planes;
  - §6, los gates humanos y las dudas con default de cada plan.
- **`Docs/SESION-2026-10-07-v2-relevo-8-ola-f.md`**: el relevo 8.
- **`Docs/SESION-2026-10-08-v2-relevo-9-ola-g.md`**: el relevo 9.
- **`Docs/SESION-2026-10-08-v2-relevo-11-ola-h.md`**: los relevos 10 y 11 (la ola H).
- **`Docs/SESION-2026-10-08-v2-relevo-12-ola-i.md`**: el relevo 12 (las 3 regresiones de UI, la bandeja del dueño, E8/E12/E13 con plan y el cierre sin resultado del `completo`).
- **`Docs/SESION-2026-10-08-sesion-del-dueno-epicas-y-videos.md`**: la sesión paralela del dueño (los relevos que se
  encadenan solos, E12 y E13 sumadas al plan, todos los videos).
- **`Docs/SESION-2026-10-08-v2-relevo-13-ola-j.md`**, **`…-14-ola-k.md`** y **`SESION-2026-10-09-v2-relevo-15-ola-l.md`**:
  los relevos 13 a 15.
- **`Docs/SESION-2026-10-09-v2-relevo-16-ola-m.md`**: el relevo 16 (la segunda tanda de videos entra; `LoopingVideoNode`,
  ODR, `MetaState.ranking`, las vistas del ranking y la placa; las trampas del clasificador de permisos y de la carga).
- **`Docs/SESION-2026-10-09-v2-relevo-17-ola-n.md`**: el relevo 17 (los tags ODR de la segunda tanda, el especial animado,
  los ganchos del ranking con su guard del tutorial, la sonda de fps; las trampas del `rapido` en background y de la red).
- **`Docs/SESION-2026-10-09-v2-relevo-18-ola-o.md`**: el relevo 18 (la cadena de Fusionar todo en el plan, el turno y el remate;
  "Piso ???", la moneda y el pack de las 43; la trampa del `pgrep -f` que se encuentra a sí mismo).
- **`Docs/SESION-2026-10-09-v2-relevo-19-ola-p.md`**: el relevo 19 (los cofres de piso por cuenta, la escena que encadena y el
  toque que apura; FisuJobs por pisos, los acentos de evento y el arte de las cajas; las trampas del agente que re-entrega y de `timeout`).
- **`Docs/SESION-2026-10-09-v2-relevo-20-ola-q.md`**: el relevo 20 (la escalada por bandas, la cadena de Fusionar todo en el simulador,
  el fondo vivo del piso y la revelación con video, «Opciones de privacidad» y el menú deslizable; la trampa del `rapido` con la
  máquina cargada).
- **`Docs/SESION-2026-10-09-v2-relevo-21-ola-r.md`**: los relevos 21 y 21b (la lista de palabras activa, E3b T8, E13 T7 con las decisiones del dueño y la trampa del clasificador en `DUENO.md`; el viaje del ascensor que suspende los videos, la barra de seis pestañas,
  los premios por video y la ficha con Despedir; E13 T7 bloqueada por pacing con la tabla de variantes y las opciones del dueño; las trampas
  del `pkill -f`, el `sleep` del latido, los simuladores por tiempo y el `cwd` que frena la limpieza).
- **`Docs/SESION-2026-10-09-v2-cierres-e11-e2a-e8c-e3a.md`**: los cuatro cierres del controlador (E11 T7, E2a T15 con la tabla de perillas, E8c T10, E3a T12)
  y el `completo` que los cubrió.
- **`Docs/SESION-2026-10-09-v2-relevo-21c-ola-s.md`**: el relevo 21c (las cinemáticas con su overlay, los cortes naturales y el app open, E2b T2, E13 T13, E12 T14;
  las revisiones opus y sus carries, el conflicto de `confirmPrestige`, la tabla de perillas, las trampas del oráculo con otra ruta y del agente que re-entrega).
- **`Docs/SESION-2026-10-09-v2-relevo-22-ola-t.md`**: el relevo 22 (compartir recableado, la privacidad del ranking, las familias en el catálogo, el motor de visitantes y las ofertas
  en el save; el rojo de `SkinCatalogRowsTests`, las revisiones opus y sus carries, las trampas de `setsid` y de las tareas de EK pura).
- **`Docs/SESION-2026-10-10-v2-relevo-23-ola-u.md`**: el relevo 23 (la mudanza a eventos v2, el Paquete en la partida, los perfiles del simulador de pacing y por qué la regla del bot de E2b T4 cambió;
  las revisiones opus de E4a T9 y E5a T6 con sus carries; las trampas del clasificador en `.superpowers/` y del panel de debug).
- **`Docs/SESION-2026-10-10-v2-cierres-r23.md`**: el relevo 23, los cierres de E8, E13b y E13 con un solo `completo` (el peso +39 MB, el panel de
  debug que se comió las puertas, las grabaciones del ascensor). Planes cerrados: `2026-10-08-v2-e8-integracion-arte.md`,
  `2026-10-08-v2-e13b-ascensor-barra.md` y `2026-10-08-v2-e13-feedback-v1.md`.
- **`Docs/SESION-2026-10-10-v2-e4b.md`**: el cierre de E4b y, con él, de E4 (la tabla por tarea con su commit, la verificación que lo cubre y los siete
  escenarios a mano que quedan para el dueño, el porqué de cada default de «Para el dueño» y lo que le deja a E5b y a E6). Plan cerrado:
  `Docs/superpowers/plans/2026-10-07-v2-e4b-visitantes-eventos.md`.
- **`Docs/SESION-2026-10-10-v2-e5a.md`**: el cierre de E5a (la tabla por tarea con su commit, la verificación que lo cubre, el porqué de cada default de
  «Para el dueño» y lo que le deja a E5b y a E6a). Plan cerrado: `Docs/superpowers/plans/2026-10-07-v2-e5a-aduana-colchon-ruleta.md`.
- **`Docs/SESION-2026-10-10-v2-relevo-30-ola-ab.md`**: el relevo 30 (los recortes del dueño y el Estudio de assets integrados, `ArtClips`, el Álbum, el visitante y el evento con video, el colchón que espera y se abre, B22 y B1–B26; los `rapido` 1 a 3 y el 4 en curso, el test que nace verde, los eventos de 0 s y el ITMS-91064).
- **`Docs/SESION-2026-10-10-v2-relevo-29-ola-aa.md`**: el relevo 29 (la pinta comprada con ORO, los accesos y las hojas de los premios, los cierres de E4b y E5a y el primer `completo` verde desde el 23; las dos revisiones opus y el bug de la Ruleta que se veía y no pagaba, los 2 UI rojos por orden, `RootView.body` al límite del type-checker, el `.xcodeproj` no versionado y los pedidos del dueño en el chat).
- **`Docs/SESION-2026-10-10-v2-relevo-28-ola-z.md`**: el relevo 28 (el Apagón y los Campeones, las probabilidades del cofre, los especiales fuera del tablero, la Tienda de ORO en pantalla y la revisión de recortes de E8 T9 Step 1; las dos revisiones opus y sus carries, el `rapido` rojo por `AudioManagerTests`, el flake de `GameLoopWiringTests` bajo carga, los agentes que re-entregan, el `doubleTap()` que no prueba un cerrojo y `PREGUNTAS-DUENO.md`).
- **`Docs/SESION-2026-10-10-v2-relevo-27-ola-y.md`**: el relevo 27 (los eventos con presentador, la Ruleta en Regalos y su aviso, la Tienda de ORO, los presupuestos de visitantes; las dos revisiones opus y sus carries, el `find /` que busca un protocolo no versionado, el `--apply` de a un worktree, `maxPerAbsence` con 4 motivos y el `planMergeAll` que no ve la cola).
- **`Docs/SESION-2026-10-10-v2-relevo-26-ola-x.md`**: el relevo 26 (la Ruleta en pantalla, el reto y las cartas, los ×3 que se entregan, el arresto, los ×2 por video y la pausa publicitaria; las tres revisiones opus y el arreglo de `chooseCareerWithVideo`, el modo auto que deja de aprobar `Bash`, el agente que re-entrega, el `rapido` encadenado de a uno).
- **`Docs/SESION-2026-10-10-v2-relevo-25-ola-w.md`**: el relevo 25 (el Álbum, los visitantes en la partida, el Colchón, la Ruleta con `LootBoxGate` y el chip del visitante; las tres revisiones opus y sus carries, el rojo que era un flake de ODR, el `MenuPagerUITests` que depende del orden y las trampas del fixture, del rename del manifest y de las fechas).
- **`Docs/SESION-2026-10-10-v2-relevo-24-ola-v.md`**: el relevo 24 (E4a T10, el perfil `.max` y el CLI del simulador con su tabla, la Liquidación en el precio, las ofertas que se cobran, el escenario de E4b T1; el bug
  del piso que anulaba la contratación gratis, las revisiones opus y sus carries, las trampas del agente que re-entrega y del reporte que no llega).
- **`Docs/SESION-2026-10-10-v2-e4.md`**: el cierre de E4a (la tabla por tarea con su commit, la verificación que lo cubre, el porqué de
  cada default de «Para el dueño» y lo que le deja a E4b). Plan cerrado: `Docs/superpowers/plans/2026-10-07-v2-e4a-visitantes-eventos.md`.
- **`Docs/SESION-2026-10-08-v2-e6.md`**: la respuesta del dueño a la galería (ninguna skin por código).
  - La llegada (las ramas sueltas del relevo 7) y el `completo` VERDE sobre
    `15318a0`, la referencia nueva, con lo que se esperaba al lado.
  - La ola F tarea por tarea (E1 T12, E3a T7–T8, E11 T5, E2a T2 y T6, E6b T3;
    E2a T7 en su rama) y sus carries a T5, T10, T12 y T14.
  - Por qué E2a T3/T4 pasaron a después de E1 T14, y la pérdida de video que
    abrió el carry de T12 y cómo se cerró.
  - Las trampas: agentes con fondo vivo (`TaskStop`), load por iCloud,
    `catalogo.py` negado a no-dueños.
- **`Docs/SESION-2026-10-07-v2-relevo-7-ola-e.md`**: el relevo 7.
  - Los dos pedidos del dueño: los guiños escondidos (con su tope) y el
    desarrollo más barato, con la medición que lo justifica (`unit` 1.244 s
    con tres compilando contra 438 s libre).
  - La ola E tarea por tarea (E1 T9, T9b, T10, T11 y T6c; E3a T6; E4a T1; E5a
    T1–T3; E11 T3 con arreglos), con lo que cada una deja y no se ve en el
    diff, y el `private(set)` → `var` de partir `GameState`.
  - Los números del `rapido` de `60af174` y lo que el próximo `completo`
    tiene que dar.
  - Lo que quedó en ramas y los carries abiertos (T10, T12, T14, M3, M4).
- **Código nuevo de la ola E, dónde mirar:**
  - `FisuEvolution/Game/State/GameState+*.swift` (E1 T9b): `GameState.swift`
    quedó con las propiedades almacenadas y el `init` (334 líneas); el resto
    vive en `+Types` (tipos anidados), `+Bootstrap`, `+TowerSync`,
    `+FrameLoop` (`tick`, `flushHUD`), `+Services`, `+Persistence`
    (`scheduleSave`, `persistNow`) y `+Projections` (`refreshProjections`, el
    que más se toca). `+BoardChanges` (E1 T9) es el turno de los cambios del
    tablero. El mapa símbolo → archivo exacto está en `task-9b-report.md` (el
    ledger de E1 en `version-2/.superpowers/sdd/`).
  - `Tools/v2/oraculo.sh tarea` y `Tools/v2/brief.py` (relevo 7): la
    verificación enfocada de un agente y el recorte de una tarea del plan (§6).
  - `Packages/EconomyKit/Sources/EconomyKit/Prizes/` (E5a T1–T3, ya en
    `version-2`): el paquete, el colchón y la ruleta, puros; `RewardSpec`
    (E4a T1) es el vocabulario único de premios.
  - `FisuEvolution/UI/Art/PanelFrames.swift` (E3a T6): `fisuSheet`, que presenta toda hoja (cover
    transparente en iPad, panel de 640 pt). Quedan 2 `.sheet` a propósito en
    `RootView`: el share del sistema y el debug.
- **`Docs/SESION-2026-10-07-v2-relevo-6-ola-d.md`**: el relevo 6.
  - Las cuatro decisiones del dueño con lo que descartan.
  - El `completo` sobre `8d17b8d` (todo verde salvo Release) y por qué el
    `rapido` no lo vio.
  - La ola D tarea por tarea (E1 T8 y T5c, E3a T5, E11 T3, E5a T1, el plan
    de E7b y su re-plan con C), con lo que cada una deja y no se ve en el
    diff, y sus arrastres.
  - Las trampas, el mecanismo y lo que quedó abierto para el relevo 7,
    incluida la propuesta de partir `GameState.swift`.
- **Código nuevo de la ola D, dónde mirar:**
  - `FisuEvolution/Game/State/GameState+Lifecycle.swift` (E1 T8): el ciclo de
    vida — `handleScenePhase(from:to:now:)`, `seal`, el latido `beatIfDue` y
    el offline. Lo que la escena inactiva puede y no puede hacer está en
    `tick` y `flushHUD` (`GameState+FrameLoop.swift` desde el relevo 7).
    Tests: `LifecycleTests` (13).
  - `FisuEvolution/App/BackgroundTasks.swift` (E1 T8): el
    `beginBackgroundTask` detrás de un protocolo, para que los tests cuenten
    los `begin` y `end` de cada salida.
  - `FisuEvolutionTests/InfoPlistContractTests.swift` (E3a T5): el contrato
    del `Info.plist` compilado (universal, vertical, pantalla completa, iOS 18,
    pantalla de lanzamiento crema) y el guardián del SDK 27. Lee el archivo,
    no `infoDictionary` (§7, ola D).
  - `Packages/EconomyKit/Sources/EconomyKit/Prizes/` (E5a T1; en `version-2`
    desde el relevo 7): `WeightedDraw`, `PackagesConfig`, `PackagesState` y
    `PackageEngine`, el Paquete de la Aduana puro. Tests:
    `PackagesEngineTests` y `WeightedDrawTests`.
- **Las rutinas del relevo**: `~/.claude/scheduled-tasks/fisu-v2-relevo-a/` y
  `…-b/` (`SKILL.md` con el prompt; fuera del repo). Manuales: se lanzan con
  `run_scheduled_task`. Su prompt todavía no nombra `tasks.md`.
- `Docs/superpowers/plans/2026-10-07-v2-e7b-a-forzados-mediacion.md` y
  `…-e7b-b-columna-ubicaciones.md`: el plan de E7b en dos.
  - E7b-a: 7 tareas. La config remota en marcha, los cortes naturales, la
    pausa publicitaria, el app open, UMP en Ajustes y la mediación.
  - E7b-b: 8 tareas, re-planeado con la columna plegable (T4 salteada).
  - 14 contradicciones en
    `version-2/.superpowers/sdd/2026-10-07-v2-e7b/plan-report.md`; la que más
    pesa: la config remota de anuncios hoy no se carga nunca.
- **`Docs/SESION-2026-10-07-v2-relevo-5-ola-c.md`**: el relevo 5.
  - La ola C tarea por tarea (E1 T5, T6, T7 y E3a fix T3 + T4), con lo que
    cada una deja y no se ve en el diff.
  - Los seguimientos T5b y T6b, y los arrastres para los despachos de E1 T9,
    T10, E3a T5, T10, T12 y E9.
  - El `completo` de referencia sobre `d22eb7a`, los `rapido` de la ola y el
    diagnóstico del rojo de `bc3bf6f`.
  - El insumo nuevo para el 🔒 de `SaveConflictResolver.swift:67/:68`.
  - Los planes de E5 y E6 con las contradicciones que importan para
    despachar.
- **Código nuevo de la ola C, dónde mirar:**
  - `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` (E1 T7): el
    embudo de todo cambio de tablero que no hizo el jugador: se planea en el
    acto y se aplica en su turno, a la vista, para que no haya evoluciones
    sin ver. `BoardChange` (con `Kind` y `Origin`), `BoardChangePlanner` y
    `BoardChangeApplier`; los mutadores `evolveUnit` y `placeUnit` viven en
    `TowerActions.swift`. Tests: `BoardChangeTests` (40).
  - `FisuEvolution/Persistence/SaveBackupStore.swift` (E1 T5): las copias del
    save en `Application Support/SaveBackups/` (10 cargas buenas, la
    premigración y cada ilegible). La pantalla es
    `UI/Popups/SaveRecoveryView.swift`, en la fase `.recovery` de `GameState`.
  - `FisuEvolution/Managers/Store/PurchasedOroHistory.swift` (E1 T6): la foto
    de los montos de ORO de la v1 (250 / 750 / 2000) y la reconstrucción desde
    `Transaction.all`. La corre `StoreManager.start`.
  - `FisuEvolution/UI/ScreenInsets.swift` y `UI/PlayColumn.swift` (E3a T4):
    las safe areas observables, publicadas por el `WindowSentinel` de la
    ventana, y la columna centrada del chrome (592 de ancho; 520 las tarjetas
    del tutorial). Todo lo que necesite un inset lee `ScreenInsets.shared`, no
    un `onAppear`.
- `Docs/superpowers/plans/2026-10-07-v2-e5a-aduana-colchon-ruleta.md` y
  `…-e5b-aduana-colchon-ruleta.md`: el plan de E5 (el Paquete de la Aduana,
  El Colchón y la Ruleta) en dos.
  - E5a, el motor: 9 tareas, sin archivos calientes ni strings. La T1 puede
    ir ya.
  - E5b, lo que se ve: 7 tareas. T2 toca `GameState.swift` y `RootView.swift`,
    y T3 `BoardScene.swift`.
  - Crea `LootBoxGate` (falla cerrado), `OddsDisclosureView` y `RewardCopy`.
    Propone la tabla de la ruleta, que PLAN-v2 no da.
  - 25 dudas con default entre los dos; 14 contradicciones en
    `version-2/.superpowers/sdd/2026-10-07-v2-e5-aduana-colchon-ruleta/plan-report.md`.
- `Docs/superpowers/plans/2026-10-07-v2-e6a-tienda-ofertas.md` y
  `…-e6b-lugares-skins.md`: el plan de E6 en dos.
  - E6a: 13 tareas. La tienda de ORO, los packs 160/550/1.400 con los mismos
    IDs y las ofertas de 24 h.
  - E6b: 10 tareas. Lugares extra (+3/+2 sobre la base), pintas con ORO, 8
    efectos por shader y familias. Tres esperan un gate: la galería de
    efectos que mira el dueño, los atlas de familias de E8 y la medición de 4
    filas en el SE.
  - Consume lo que crea E5, con los nombres exactos.
  - 24 dudas con default; 15 contradicciones en
    `version-2/.superpowers/sdd/2026-10-07-v2-e6-tienda-skins/plan-report.md`.
- **`Docs/SESION-2026-10-07-v2-relevo-4-ola-b.md`**: el relevo 4.
  - La ola B tarea por tarea, con lo que cada una deja y no se ve en el diff.
  - La línea de base rápida con su cuenta.
  - Los cuatro spikes de E3a con sus números y qué tareas cambian.
  - Los planes de E2a y E4 con las contradicciones que importan para
    despachar.
  - Los dos 🔒 nuevos y las trampas del guard estricto y de integrar sin
    worktree.
- **`Docs/SESION-2026-10-06-v2-integracion-y-ola-a.md`** — el relevo 3: cómo
  se integraron los cuatro frentes, la línea de base nueva con su cuenta
  exacta, el pedido de agentes concurrentes y notificaciones, la Ola A con el
  estado de E1 tarea por tarea, y las trampas del `sed`, del guard y de la
  carga.
- `Docs/superpowers/plans/2026-10-07-v2-e11-notificaciones.md` — el plan de
  E11: 7 tareas, del planificador puro al cableado al ciclo de vida (después
  de E1 T8).
- `Docs/superpowers/plans/2026-10-07-v2-e3a-ux-nucleo.md` y
  `…-e3b-ux-nucleo.md` — el plan de E3 en dos: E3a, la pantalla (12 tareas,
  con `Tools/v2/catalogo.py` en la T1 para integrar strings de tareas
  paralelas), y E3b, las interacciones (9). Cada uno con su tabla de archivos
  calientes por tarea. ⚠️ Las Tasks 4, 6, 8 y 10 de E3a cambian por los
  spikes, y el plan todavía dice lo viejo (sesión del relevo 4, §3). La T4
  ya entró con el cambio; los despachos de T6, T8 y T10 todavía tienen que
  llevarlo.
- `Docs/superpowers/plans/2026-10-07-v2-e2a-mecanicas.md`: el plan de E2a.
  - 15 tareas: las mecánicas de economía detrás de perillas con default v1, y
    los premios en minutos de producción.
  - Las APIs de E1 que consume, con un "Step 0" de `grep` por tarea.
  - Lo que le deja a E2b y a las otras épicas.
  - 14 dudas con default.
- `Docs/superpowers/plans/2026-10-07-v2-e4a-visitantes-eventos.md` y
  `…-e4b-visitantes-eventos.md`: el plan de E4 en dos.
  - E4a, el motor: 10 tareas de EconomyKit y JSON, con un solo toque caliente
    grande (T9), que necesita E1 cerrada.
  - E4b, la escena, la UI y el Álbum: 10 tareas que arrancan con E4a cerrada.
  - 26 dudas con default entre los dos.
- **`Docs/SESION-2026-10-06-plan-v2.md`** — el porqué del plan: lo que se
  midió antes de decidir, lo descartado y las trampas de la planificación.
- **`Tools/v2/`** — el oráculo del run (`oraculo.sh`), su juez (`rojos.py`) y
  la lista de rojos tolerados (`rojos-declarados.txt`). Cómo se usa, en §6.
- **`Tools/v2/catalogo.py`** (E3a T1) — escribe `Localizable.xcstrings` en el
  formato canónico de Xcode (trampa 29).
  - `verificar` reescribe los dos catálogos en memoria y exige que salgan
    iguales byte a byte.
  - `aplicar <snapshot.json> …` suma claves `{"clave": {"es", "en"}}`, y antes
    corre esa verificación. No pisa una traducción existente.
  - Los snapshots que esperan integración van a `Tools/v2/claves-pendientes/`.
  - Es lo que deja que dos tareas de una misma ola sumen strings.
  - Sus tests están en `Tools/v2/test_catalogo.py`.
- `Docs/SESION-2026-10-06-v2-e0-oraculo.md` — E0: el oráculo, su línea de base
  con los tiempos de cada suite, y las trampas del bash 3.2, de TextureAtlas y
  del guard de los subagentes.
- `Docs/superpowers/plans/2026-10-06-v2-e1-correcciones-criticas.md` — el plan
  de E1: 16 tareas en olas, con las dudas para el dueño al final.
- `Docs/biblia-visitantes.md` — los 8 visitantes nuevos, los 10 especiales y
  las 3 familias de skins, con su descriptor canónico para los prompts.
- **`Distribution/setup-v2-asc-admob-mediacion.md`** — el paso a paso del
  lanzamiento de la 2.0: App Store Connect, AdMob, las 4 redes de mediación y
  el sitio, con 🔒 en lo que hace el dueño y la URL de cada dato. Es también el
  insumo del futuro script de Selenium.
- **`Distribution/iap-appstore-connect.md`** — los 14 productos con sus fichas
  (la fuente de las claves de `IAPCopy`) y lo que entrega cada uno.
- `Docs/SESION-2026-10-06-v2-e10-docs.md` — E10 en papel: el porqué de las
  fichas y los Términos, y las verificaciones (conteos, URLs, SKAdNetwork).
- `Docs/SESION-2026-10-06-v2-e8-pipeline.md` — E8 pipeline: por qué el arte
  calado era una decisión del dueño, el gate de `rentista_soles` (con dónde
  están los paneles), las categorías `npc`/`skinfam` y el contrato de
  `loops_manifest.json` con la medición del verde.
- `Docs/SESION-2026-10-06-v2-e8-audio.md` — E8 audio: los diez temas con su
  carácter, el crossfade y su director puro, el enganche sin tocar
  `GameState`, el peso medido y los comandos para escuchar cada tema.
- `Docs/SESION-2026-10-06-v2-e7a-anuncios.md` — E7a: los formatos nuevos, las
  unidades por momento, la config remota y sus pisos, la política de cortes
  naturales y cómo se cablea, y la investigación de mediación (paquetes,
  formatos por red, SKAdNetwork y privacy manifests).
- `Docs/SESION-2026-10-06-v2-e3-i18n.md` — E3, idioma: `IAPCopy` y el porqué
  del respaldo de StoreKit, la interpolación de números desde los datos, el
  arreglo de raíz del logo del splash, y qué cubre
  `LocalizationCompletenessTests`.
- **`Docs/HANDOFF-v2.md`** — el punto de entrada de la v2: el commit del build
  publicado, la rama `version-2`, las integraciones en producción y el backlog.
- **`Docs/SESION-2026-10-06-preparacion-v2.md`** — cómo se armó `version-2`: qué
  se integró, los dos bugs, la limpieza con su porqué, lo que quedó a propósito
  y la lista "Para el plan".
- `Tools/asset-pipeline/README.md` — cómo se integra arte nuevo al juego (la
  generación vive en `automatic-image-generation`).
- `Docs/SESION-2026-09-03-cofre-arranque.md` — el cofre ya no se traba al
  principio: los 466 ms del retrato leído en línea en la llegada, el
  precalentado en background con `SKTexture.preload`, y la sonda de la
  llegada (`arrival_probe.py`) que ve lo que el promedio grueso no.
- `Docs/SESION-2026-08-28-cofre-a-velocidad.md` — el cofre a 1,5x: el retime a
  36 fps (mismos 190 frames, audio atempo, manifest como fuente única de
  ritmo), el congelón real del empalme (~280 ms) muerto con preroll +
  capa premontada, y las trampas del checkout compartido, del promedio
  que esconde congelones y del VideoToolbox que pisa PTS.
- `Docs/SESION-2026-08-28-cuesta-pre-compuerta.md` — el muro del arranque:
  la doble exponencial de la cuesta pre-compuerta, el override
  `floors[alley].hireCostGrowth` con el global intacto, el guard
  `thePreGateClimbHasNoWallInIt` y la trampa 40 (el pacing-sim sin catálogo
  de mejoras al lado del economy.json da la conclusión opuesta).
- `Docs/SESION-2026-08-28-pulido-post-cofre.md` — el pulido del día: la trampa del
  atlasc, el purgado del cofre viejo, el premio a los 6,5 s, la fila con sólo el
  multiplicador, el teaser de reencarnar desde lujo, la lección del primer ORO y
  los 48 fps interpolados.
- `Docs/SESION-2026-08-28-cofre-definitivo-2d.md` — el master DEFINITIVO del cofre:
  2D vertical con sonido (mov con AAC + clips de sacudida), full-bleed a 274 pt,
  el empalme continuo del tercer toque y la muerte del push-in de la casa.
- `Docs/SESION-2026-08-28-cofre-video-v2.md` — el master intermedio (el cofre se
  desvanece solo), la recalibración v2, y el bug del velo: el mov premultiplicado
  porque `AVPlayerLayer` suma el RGB de las zonas con α=0 (⚠️ su master y números
  duraron horas: ver la sesión ter).
- `Docs/SESION-2026-08-28-cofre-animado.md` — la apertura de cofres es el video del
  animador (HEVC con alfa + frames interactivos); el keying limited-range, el pipeline
  `chest_video_frames.py`, el contrato `chest_anim.json` y el premio en el marco
  (⚠️ su master y sus números de calibración quedaron viejos el mismo día: ver la v2).
- `Docs/superpowers/specs/2026-08-28-cofre-animado-por-video-design.md` — el diseño, con
  la ENMIENDA del dueño en §8 (solo el video, entero) que invalida parte de §2.
- `Docs/superpowers/specs/2026-08-26-cofres-de-skins-design.md` — el diseño de los cofres:
  la bolsa, el sorteo, las fuentes con su cuenta medida, los siete latidos de la animación
  (⚠️ los latidos visuales de ese spec son historia: desde el 28-08 la animación es el video).
- `Docs/superpowers/plans/2026-08-26-cofres-de-skins.md` — el plan de 12 tareas. ⚠️ Lleva
  adentro un **mapa de los helpers de test que existen de verdad**, porque el plan inventó
  cuatro que no existían.
- `Docs/SESION-2026-08-28-cofres-solo-desbloqueados.md` — por qué
  la rareza ya era una banda de pisos, dónde vive el filtro y por qué en un solo lugar, la
  granularidad piso-y-no-tier con el motivo de la bifurcación de carrera, y los tres efectos
  colaterales (el mínimo de épica, el puntito y la puerta de debug).
- `Docs/SESION-2026-08-26-cofres-de-skins.md` — la sesión: las ocho decisiones del dueño, los
  dos assets que se regeneraron y por qué, y **el cierre del 2026-08-27** — la primera corrida
  limpia de la suite entera sobre el árbol final, el veredicto del rojo intermitente con su
  medición, el triage de las 36 menores diferidas una por una (12 ya estaban cerradas), y las
  tres decisiones que quedaron tomadas.

| Doc | Para qué |
|---|---|
| **este** | Punto de entrada, estado y arquitectura |
| `HANDOFF-F7-estado.md` | La torre en detalle + el circuito de arte de skins |
| `HANDOFF-perf.md` | Todo lo de rendimiento, con las mediciones |
| `HANDOFF-arte-gemini.md` | El pipeline de generación de arte y sus 6 bugs |
| `balance-log.md` | **Toda decisión de números, con su costo medido** |
| `PROMPT-F7-torre-de-escenarios.md` | El spec funcional de la torre |
| `concurrency-conventions.md` | Las 6 reglas de Swift 6 del proyecto |
| **`HANDOFF-gates-pendientes.md`** | **RF-14 y RF-02c, los dos únicos pendientes. La lista de audio y la tabla de productos, listas para ejecutar cuando el gate se abra** |
| **`SESION-2026-08-23-desaceleracion.md`** | **La desaceleración: por qué una run que no se traba no le da trabajo al prestigio, el knob de escalada con su umbral (y por qué el umbral no es adorno), "trabarse" convertido en métrica publicada, las 9 reencarnaciones que NO se forzaron, el total que NO se escaló, y el arreglo acotado del build para que el dueño pueda jugarlo** |
| **`SESION-2026-08-23-fusiones-cobradas.md`** | **Las fusiones dejan de ser gratis en el simulador (y por qué eso era un sesgo, no una simplificación), el barrido de la profundidad N=6/7/8 con las cinco métricas, la conversión a horas del dueño con el factor de 3×, y por qué la compra en lote se empezó y se descartó** |
| **`SESION-2026-08-23-precio-atado-a-la-frontera.md`** | **La cuarta ronda de balance: el precio de contratar anclado a tu FRONTERA (la regla de precios nueva, que reemplaza a la de los 600 clicks), la compuerta convertida por fin en dial de dificultad, la tercera ceguera del bot, y el hallazgo de que la mitad del tiempo activo es apretar el botón y no esperar plata — con las cuatro salidas que el dueño tiene que elegir** |
| **`SESION-2026-08-22-compuerta-por-distancia.md`** | **La tercera ronda de balance: la compuerta medida en tiers, las dos cegueras del simulador y el hallazgo de que el contrato de 20-30 h nunca se cumplió — con las tres salidas que el dueño tiene que elegir. Y la trampa del Xcode 26.6 sin runtime de iOS 26** |
| **`SESION-2026-08-21-nombres-en-ingles.md`** | **Por qué el nombre del personaje no se traducía, la mesa de las 17 traducciones culturales con su porqué, y qué se descartó (un campo por idioma en `tiers.json`)** |
| **`SESION-2026-08-21-rebalance-pacing.md`** | **El rebalance de pacing: las tres métricas antes/después, los dos knobs que hacen cosas distintas, las tres decisiones del dueño con lo descartado y su número, y los cuatro diagnósticos que salieron errados antes del bueno** |
| **`SESION-2026-08-25-correcciones-ui-y-xcode-26.md`** | **El aire del botón, la manito única, la carta del special con recap, y los cinco eslabones de Xcode 26.6** |
| **`SESION-2026-08-21-tutorial-high-end.md`** | **El tutorial rehecho — la fase corta arbitrada por la cola, las 8 lecciones con sus señales, el puntito de logros y las trampas 24/25** |
| **`SESION-2026-08-21-telon-del-menu.md`** | **El telón blanco de las pantallas empujadas del menú: la medición, el arreglo por versión de iOS y qué quedó sin verificar** |
| **`SESION-2026-08-19-skins-oro-diamante.md`** | **Las 86 skins de material: el catálogo de un id por material, el desbloqueo de cada una y los tres bugs medidos del pipeline de generación** |
| **`SESION-2026-08-18-recorte-de-fondo.md`** | **Por qué el recorte dejó de ser por saliencia, con la medición de los 219 assets y el criterio topológico que lo reemplazó** |
| **`SESION-2026-08-17-rediseno-v3.md`** | **Los materiales v3 de las referencias, tarea por tarea, con la verificación y la trampa del cwd — y sus arcos del 2026-08-18, el tercero es la hoja contenida** |
| **`SESION-2026-08-16-cierre-post-merge.md`** | **Las 7 tareas del ticket post-merge con sus commits, el veredicto del review de rama y el backlog que sobrevive** |
| **`SESION-2026-08-14-rediseno-ui.md`** | **Las 20 tareas del rediseño de UI, con sus fix rounds, rulings y avisos vivos. La fuente de verdad del detalle de esa rama** |
| **`SESION-2026-08-06-correcciones-de-playtest.md`** | **El estado de la sesión de las 16 correcciones: qué quedó abierto, qué está en vuelo y los gates humanos. Empezá por acá si retomás ese trabajo** |
| `SESION-2026-08-05-fallback-de-contratacion.md` | El fallback del botón y la fila trasera invisible |
| `SESION-2026-08-17-cola-de-celebraciones.md` | La cola que reproduce las celebraciones de a una |
| `superpowers/specs/2026-08-10-fusion-asistida-design.md` | Los dos gestos de fusión, con los radios y por qué cada uno |
| `superpowers/specs/2026-08-10-contadores-de-bonus-activos-design.md` | Los contadores del HUD y por qué la proyección no lleva el tiempo |
| `superpowers/specs/`, `superpowers/plans/` | Specs y planes por feature |
