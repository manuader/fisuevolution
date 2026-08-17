# SESIÓN 2026-08-16 — Cierre post-merge del rediseño (✅ COMPLETO)

> **Para retomar con un agente nuevo, leé `Docs/HANDOFF.md` primero y esto
> después.** Acá está el detalle de UNA rama: `fix/cierre-post-merge`, que
> ejecuta lo que el cierre del rediseño de UI dejó explícitamente triageado
> para después del merge.
>
> ✅ **Las 7 tareas del plan están hechas y revisadas.** ✅ **Y el review
> integral de rama también**: veredicto **READY TO MERGE con CERO ola de
> fixes de código** — el único trabajo que ruteó fueron items de
> documentación, que son la tarea 7.
>
> Suites finales, las cuatro medidas en la MISMA verificación: EconomyKit
> **183** · app **346** · UI **43/43 en una sola corrida y sin skips** ·
> pipeline 27 (1 rojo conocido) · **cero warnings**.
>
> Lo que queda no es implementación: está en "Qué queda", al final.

## Cómo se retoma

1. Rama: `fix/cierre-post-merge`, 18 commits sobre `89f215a` (main post-merge
   del rediseño). ✅ **Mergeada a `main` (`e4d4ce6`) y PUSHEADA** — y detrás
   fueron también los dos commits del runner endurecido (`78119ef` +
   `acaf3e6`, ver "El batch" abajo). `origin/main` quedó al día por primera
   vez en la historia del repo: la trampa 7 está cerrada.
2. Plan (7 tareas): `Docs/superpowers/plans/2026-08-16-cierre-post-merge.md`.
   No hay spec propio: el insumo es el triage del review integral anterior.
3. Proceso: skill `superpowers:subagent-driven-development`. Workspace:
   `.superpowers/sdd/2026-08-16-cierre-post-merge/` (gitignorado) con
   `progress.md` (ledger: minors diferidos, rulings, drift verificado) y un
   `task-N-report.md` por tarea. Si el workspace no existe, se reconstruye de
   este doc + `git log`.
4. Política de modelos: implementadores y reviewers en **opus**; escalada de
   fix rounds 4-5 a fable. Un implementador por vez, SECUENCIAL.
5. La sesión anterior —las 20 tareas del rediseño— está en
   `Docs/SESION-2026-08-14-rediseno-ui.md`. Sus decisiones del dueño y su
   regla visual (FisuJobs es la referencia canónica) siguen vigentes acá.

## Estado por tarea

| # | Tarea | Estado | Commits | Notas |
|---|---|---|---|---|
| 1 | Integrar el calendario del daily | ✅ review clean | `202837e` (sobre `07789d7`) | Cherry-pick de `84a2af6` (rama paralela `fix/iconos-gameicon`), que NUNCA había pasado por el pipeline: acá sí. El icono va a 44 pt en el plato de 56 de `BoostGlyph`/`ScreenGlyph`, con la nota "se cobra solo" corrida al costado. Era **el último de los 15 iconos sin call-site**. ⚠️ VoiceOver ahora lee la nota ANTES de los 7 días —consecuencia del reacomodo, nada lo pinea, aceptado como mejora—. `07789d7`, justo antes, es el reformateo de `extractionState` que había dejado el último build de Xcode: de ahí salió la trampa nueva de más abajo |
| 2 | Retirar el cluster spawn muerto | ✅ review clean | `283af80` | Se fueron `HireOffer`, `showSpawnHint`, `hireOffer` y su cálculo de `GameState`. **Ninguna aserción se perdió**: los pins del gate y del fallback se mudaron a `TowerActions`, la capa donde la conducta vive de verdad, verificados byte a byte contra `GameState.hireTargetOrdinal`. ⚠️ Lo que sí quedó huérfano es un requisito de UX — restaurado en la tarea 7 |
| 3 | `StatePill` → `StateBadge` en Upgrades | ✅ review clean | `f36310b` | Una sola gramática de badge en el juego. Ids de estado NUEVOS en vez de reusar los de compra (un mismo id no puede resolver a `button` en un estado y a texto en otro); a11y por `.combine` + identifier, con precedente en `GiftsView`. Y tocar la cápsula ya no castiga con haptic+audio de error |
| 4 | Pase de accesibilidad en lote | ✅ review clean (1 fix round) | `f336887` + `f888980` + `88a320f` | `PricePill` dice la moneda y **qué** compra; `ProgressBar` con label; se fueron las paradas mudas; el número de piso y el "estás acá" del ascensor escalan con Dynamic Type. El fix round no fue de código sino de **prosa**: los docstrings del ascensor declaran el canje ENTERO (tamaño **y** peso) y por qué `Tokens.display` perdió. Decisión declarada: **sin override de peso por call-site** — la gramática manda y el arreglo futuro es subir el token |
| 5 | Residuales de la ola del review | ✅ review clean | `563542d` + `6eeecb1` + `f5ddab8` + `31f82c2` + `0d7d6c5` | Tarjeta de tienda degradada centrada aunque haya banner; riel fijo de **104** (derivado del `minWidth` 92 del `PricePill`, como el 96 de FisuJobs) que devuelve los títulos a un renglón; `MetaState.init(from:)` con `decodeIfPresent` + e2e del migrador desde JSON crudo v3; y `ui_pill_currency` fuera del manifest y del atlas, y **anotado como "retirado" en el índice** (la fila 113 y su `.md` siguen ahí: son historia de otra tanda). El follow-up del atlas fue **extensión de alcance autorizada** por el controller (zona del pipeline levantada SÓLO para eso) y se verificó **sobre el producto compilado**: ausente de `ui.plist`, páginas −73 KB, cola 213–227 intacta por diff |
| 6 | Recuperar `AscentRenderingUITests` | ✅ review clean (1 fix round) | `b7df49b` + `2bf663e` | **Volvió de entre los muertos tras diez días salteado.** Tres causas, no una; la tercera y decisiva no la tenía ningún diagnóstico previo: el callejón cubre los tiers **1..4**, así que el primer ascenso pide **cuatro** fusiones. El test ya no hardcodea el número —fusiona hasta que la pill cambia de piso— así que un rebalanceo no lo vuelve a romper. El fix round mató dos asserts que podían pasar sin haber comprobado nada (`unitCount` devolvía `-1` en la lectura fallida, menor que cualquier `before`) y desató el test del reloj. 3/3 verde, una de ellas en load average 48 |
| 7 | Verificación final, docs y cierre | ✅ | `ac3dfb6` + (este commit) | Las cuatro suites enteras (números arriba). `ac3dfb6` corrige **cuatro premisas falsas** en prosa escrita en esta misma rama —comment-only, cero comportamiento—; este commit cierra los docs. El review integral de rama ruteó SÓLO items de documentación: no hubo ola de fixes de código |

## El review integral de rama

Veredicto: **Ready to merge — sí**, sobre el diff entero `89f215a..HEAD`, y
**sin una sola corrección de código ruteada**. Es la diferencia más grande con
el cierre anterior, donde el review integral disparó una ola de 13 puntos.

Lo que sí ruteó fueron tres items de documentación y cuatro de prosa Swift, y
los siete son de la misma familia: **frases verdaderas cuando se escribieron
que dejaron de serlo**, o requisitos que una reescritura barrió de paso. Los
cuatro de prosa están en `ac3dfb6` con su medición al lado (el contraste
tinta/amarillo es 10:1 y no "el par más alto de la paleta"; tinta/crema da
13,2:1). Los tres de docs son el requisito de UX del fallback de contratación,
el conteo de clases de la suite de UI y la trampa nueva de las claves `stale`.

## La trampa que salió de esta rama

⚠️ **`stale` NO quiere decir borrable.** El reformateo que dejó el último build
de Xcode (`07789d7`) marcó `extractionState: stale` en **175 de las 459
claves** del catálogo, y muchas están **vivas**: `settings.haptics`,
`daily.title`, `notif.daily.title`/`.body` y ~20 de ajustes. El extractor no ve
a través de un parámetro `titleKey:` —la clave viaja como `LocalizedStringKey`
hasta una vista propia en vez de ser literal de `Text`— ni siempre a través de
`String(localized:)`. Una limpieza que borre por `extractionState` **se lleva
claves vivas y deja la clave cruda en pantalla**. Quedó anotada en la trampa 5
de `HANDOFF.md`, que es donde vive la familia.

## Deuda que sobrevive a la rama

Del triage del review final. **Ninguna es tarea abierta del HANDOFF** —por eso
va acá y no allá—: son follow-ups sin dueño, ordenados por lo que rinden.

1. **Pin de precio en `CustomizationUITests`** (~3 líneas, y es el de mejor
   relación valor/costo de la lista). La regresión de Pintas que la ola arregló
   —un label externo que borraba el precio— no tiene pin en SU pantalla: un
   `contains(row.value)` como el de FisuJobs la cierra.
2. **`testEachFloorRendersOnlyItsOwnBackground` conserva el patrón viejo** que
   la tarea 6 le retiró al test de ascenso: `isEnabled` sin espera, dos
   `sleep`, label en inglés. Y lanza con `--uitest-unlock-tower`, que habilita
   las skins de milestone: si ese sheet se presentara al launch, taparía
   `tower.arrow.up` sin guarda. Verde 6/6 hoy — es riesgo, no rojo.
3. **Identidad de piso por `accessibilityValue` en `HUDView`.** Hoy el piso
   sólo sale como `accessibilityLabel`, así que los tests comparan el display
   string **en inglés**. Un `accessibilityValue` con el floor id sirve a dos
   tests a la vez.
4. **Constante compartida del riel**, derivada del `minWidth` del `PricePill`.
   Hoy son tres números literales en tres archivos: 96 (FisuJobs), 92 (el
   `minWidth`) y 104 (tienda). Están bien elegidos y documentados, pero nada
   los ata.
5. **`TowerNaming` mapea `"cosmic"`**, que la tabla de 10 pisos no contiene:
   rama muerta legacy de la decisión del dueño que retiró ese fondo.
6. **Los glifos del `StateBadge` de restauración en `SettingsView`** (:324/:333)
   quedaron como paradas mudas de VoiceOver — fuera de alcance declarado del
   pase a11y de la tarea 4.
7. **Un launch arg que siembre `lastErrorMessage`**: hoy
   `--uitest-storekit-empty` llega a `.failed` pero nunca setea el mensaje, así
   que el fix del centrado de la tienda no tiene guard automático.

Los minors menores —el `waitUntilEnabled` sin backoff, el timeout muerto de
`dismissSkinAward`, la tercera copia de la cadena del plato en `GiftsView`, los
conteos absolutos de segmentos AX en `FisuJobsUITests`— viven en el ledger del
workspace SDD con su razonamiento completo.

## El batch: el intento, y el runner que salió endurecido

Después del merge y el push, el controller **intentó el batch** por la ruta
nueva de la trampa 11 (un `.command` lanzado con `open`, para que Terminal.app
sea el responsible process de TCC). Resultado, medido:

- **La ruta del permiso FUNCIONA**: `osascript` tipeó desde la sesión del
  agente (2146 de 2150 caracteres del asset 2 llegaron al editor).
- **Lo que falló fue el foco**: con otros frontends activos en la máquina,
  dos assets tiparon 0 caracteres (las teclas cayeron en otra ventana) y uno
  perdió 4 por el camino. El guard `prompt_landed` abortó **antes de enviar**
  las tres veces: 0/15 generados, **cuota gastada: cero**, cola intacta.

De ahí salió el endurecimiento del runner, con el pipeline de siempre
(implementador + review adversarial + fix round + re-review):

- `78119ef` — tipeo en **tandas de 250** (knobs `--type-chunk`/`--type-pause`)
  con verificación de frontmost antes de cada tanda, re-activación si otra app
  se puso adelante, y abort **nombrando a la app ladrona** tras 3 intentos.
- `acaf3e6` — el fix del Critical que el review confirmó: la recuperación de
  foco podía insertar una tanda EN EL MEDIO del texto y `prompt_landed` (largo
  exacto + cabeza intacta) lo aceptaba → cuota en un prompt barajado. Ahora se
  verifica el **prefijo** del editor tras cada recuperación y tras la tanda
  siguiente; la recuperación no manda ninguna tecla hasta confirmar Chrome al
  frente; y las recuperaciones se avisan por stderr (`⚠️ foco robado por «X»`).
  El re-review re-ejecutó el ataque original: `GenerationBlocked` con cuota
  cero, y un fuzz de **1.000 robos aleatorios mandó cero prompts corruptos**.
  Suite del pipeline: 27 base + 18 tests nuevos, con las redes probadas contra
  mutantes.

**Invariante que quedó**: el peor caso del runner es abortar con cuota cero —
nunca enviar un prompt a medias ni barajado. Y el batch sólo AVANZA con la
máquina quieta: cada robo de foco quema un reintento.

Deuda menor del runner (en el ledger, con el loosening quirúrgico anotado por
el re-review): `_verify_prefix` es exacto-tras-norm y divergiría de
`prompt_landed` si Gemini mutila una raya larga durante una recuperación
(cuota cero, sólo camino de recuperación); la recuperación de la tanda 1 no
tiene tecla descartable; `activate`/`keystroke` siguen sin timeout de
subprocess; hay 20 `.pyc` trackeados de antes.

## Qué queda

Dos cosas, y **ninguna de las dos es código**.

1. ✅ **HECHO — el batch de los 15 iconos corrió entero** (2026-08-16,
   `d304fe3`): el dueño lo lanzó desde Terminal.app con el runner endurecido;
   12 entraron a la primera, y los 3 que fallaban dos corridas seguidas
   tenían una causa nueva — **el keystroke pierde las vocales con tilde** en
   el Chrome/Quill actual, y los tres eran los únicos con una dentro de los
   primeros 40 caracteres (la cabeza que `prompt_landed` compara exacta).
   Transliterados a ASCII (`0623854`, bug #7 de `HANDOFF-arte-gemini.md`),
   entraron los tres al toque. Opacidad medida en los 15: 18–51% de píxeles
   opacos (umbral de hueco 12) — **cero descartes**, incluidos los tres
   candidatos de riesgo. Suites de las pantallas tocadas
   (BottomMenu/Menu/HUDRedesign/BonusHUD/FloorMap): verdes — el único rojo
   fue la trampa 9a en frío y pasó 2/2 aislado. Los vectoriales de
   `GameIcons.swift` quedan de fallback. El punto que sigue es histórico:
   Receta completa y medición de opacidad post-batch en `HANDOFF.md` §8. Al
   cierre de esta sesión la **cola 213–227 está intacta y verificada**: los 15
   `.md` numerados —los 15 en `- **estado**: pendiente` y **ninguno con campo
   `referencia`**, que es lo que los distingue de los 150 `.md` que sí lo
   llevan: los iconos de UI no adjuntan el Fisura— con sus 15 entradas gemelas
   en `prompts.json`, **cero PNG generados** para esas claves en `ui.atlas`, y
   el único archivo que esta rama tocó bajo `prompts/` es `00_INDICE.md`, por
   la baja de `ui_pill_currency` de la tarea 5. La **costura ya está completa**: con el
   calendario de la tarea 1 no queda ningún icono sin
   call-site, así que el día que el batch corra, los 15 entran solos.
   ✅ **El intento del controller ya pasó** (ver "El batch", arriba): cuota
   cero, runner endurecido, y el GO quedó dado — el Chrome dedicado abierto en
   `:9222` y logueado, el `--dry-run` listando los 15, y el comando exacto en
   manos del dueño, que lo corre desde Terminal.app **con la máquina quieta**.
   ⚠️ Sigue haciendo falta **medir el % de píxeles opacos del `@2x`** antes de
   integrar: `rembg` se come los rellenos interiores claros y grandes, y los
   de riesgo alto son `ui_menu_stats`, `ui_trophy_silver` y
   `ui_daily_calendar`. Esa verificación, el descarte de los huecos, el build
   con suites de las pantallas tocadas y el commit+push del arte son el cierre
   post-batch, y quedaron hablados para que los haga el agente cuando el
   dueño avise que el batch terminó.

2. ⏳ **Los dos gates humanos de F6**, que son los mismos de siempre:
   - **RF-02c** — la cuenta de Apple Developer (USD 99). Nada técnico pendiente.
   - **RF-14** — música y efectos. ⚠️ **Re-verificado el 2026-08-16 y el gate
     sigue cerrado, igual que el 2026-08-07**: el MCP de audio disponible en la
     sesión hace **sólo TTS**, y su contrato prohíbe explícitamente usarlo para
     música o efectos standalone (los modelos de música y de SFX existen, pero
     para otro pipeline, no para este). O sea que no es "no busqué bien": no
     hay fuente de audio utilizable acá. Lo destraba un MCP con música/SFX
     standalone, o audio CC0 a mano. La lista de los 12 archivos con su evento
     y su duración está lista en `Docs/HANDOFF-gates-pendientes.md`.

✅ **La trampa 7 quedó cerrada en esta sesión**: `main` está pusheado
(`origin/main` = `acaf3e6`, distancia 0). El próximo frente arranca, por
primera vez, de un árbol al día.
