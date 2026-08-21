# PROMPT — El tutorial high-end: enseñar toda la app cuando toca, sin pisarse con nada

> **Para el agente que lo tome**: esto es un pedido del dueño con la
> investigación ya hecha (2026-08-21): el tutorial actual se jugó entero en
> simulador con capturas de cada paso, y hay un inventario con file:line de
> todo el sistema (tutorial, celebraciones, logros, señales de gating). Los
> números de abajo están MEDIDOS. Antes de tocar nada leé `Docs/HANDOFF.md`
> (§0 protocolo, §5 decisiones, §6 cómo verificar, §7 trampas — la 9/9a de
> identifiers y la 23 de SwiftUI te tocan directo) y cerrá tu sesión con el
> sistema de handoffs (`~/Desktop/skills/documentation`).

---

## 1. Lo que pidió el dueño, textual

> "hay que mejorar el tutorial teniendo en cuenta la nueva ui. tambien hacer
> que no se superpongan las animaciones de desbloqueo de personaje y
> achievements desbloqueados con las animaciones del tutorial."
>
> "la idea es que te enseñe a usar toda la app. hace que solo utilice las
> fotos del fisura. hay alguna que otra foto que no esta bien."
>
> "un tutorial high end que explique correctamente cada pantalla del juego en
> el momento en el que es necesario explicarlo (por ejemplo: no mandar al
> usuario a la pagina de upgrade si no tiene el dinero suficiente para comprar
> uno, o no mandarlo a la pagina del ascensor si no tiene ninguno otro piso
> desbloqueado que el usuario pueda seleccionar, no mandarlo a la pagina de
> achievements si todavia no puede claimear ninguno, no ir a la pagina de
> outfits hasta no tener un outfit desbloqueado, etc). es muy importante el
> pacing del tutorial y la ui del mismo. se debe ver como un juego
> extremadamente profesional y high end, al mismo tiempo, debe respetar el
> rediseño de la ui."
>
> "con respecto a los achievements. tambien hace que cuando haya alguno para
> claimear que se ponga un puntito rojo del estilo 'notification' en el icono
> del menu y al entrar en el boton de achivements para hacerle saber al
> jugador que es necesario entrar ahi para ganar la recompensa. inclui esta
> dinamica al tutorial"

---

## 2. El estado real, medido hoy (recorrido completo en simulador, 2026-08-21)

### 2.1 El guion son 6 pasos y enseña 3 verbos

`TutorialOverlay.swift:74-95` (el guion), avance por acción en `:289-300`:

| # | paso | pose | avanza cuando | problema |
|---|---|---|---|---|
| 0 | tap | `fisura_wave` | tocó Y junta para contratar | — (bien pensado, ver docstring de `earnedEnoughToHire`) |
| 1 | hire | `fisura_point` | contrató | la hoja tapa al guía (§2.3) |
| 2 | merge | `fisura_explain` | fusionó | la foto está rota (§2.4) y el reveal se pisa (§2.6) |
| 3 | upgrades | `fisura_explain` | **abrió** la hoja (`RootView.swift:390` inserta el evento ANTES de presentar) | timing mal (§2.2) |
| 4 | map | `fisura_point` | **abrió** el mapa | timing mal (§2.2) |
| 5 | finish | `fisura_celebrate` | botón "¡Vamos!" | — |

Lo que el tutorial NO enseña nunca: **Pintas/Outfits, Regalos/Bonus, Tienda,
el Menú entero (organigrama, estadísticas, logros, ajustes), el atajo
`hud.quickhire`, el prestigio, los boosts, el daily y los eventos**. El pedido
es "toda la app": hoy cubre 3 verbos y 2 aperturas vacías.

### 2.2 Los dos pasos con el timing mal (la queja textual, medida)

- **Upgrades (paso 3)**: en una partida real el jugador llega con ~0-10
  monedas (ganó ~25-30 tapeando, gastó 25 en contratar). La hoja más barata:
  mejora de El Fisura **50**, passive **60** (capturado: 50/60/140/168).
  **No puede comprar nada**, y el paso encima se da por aprendido con sólo
  abrir la hoja. La "lección" es abrir, mirar precios imposibles y cerrar.
- **Ascensor (paso 4)**: el texto vende "saltá directo a cualquier piso" con
  **1/10 pisos desbloqueados** (capturado: todo "Locked" + "You are here").
  El primer piso nuevo llega con un T5, MUCHO después del tutorial.

### 2.3 Adentro de las hojas, el guía desaparece

Las hojas se presentan ENCIMA del overlay (decisión documentada en
`TutorialOverlay.swift:62-73`). En el paso 1 el jugador entra a FisuJobs y el
tutorial se esfuma: ni tarjeta, ni spotlight sobre la fila pagable (la fila
verde de affordable es lo único que lo orienta). Igual en Upgrades. Capturado.

### 2.4 Las fotos del Fisura: dos de cuatro están mal (medido)

| asset (640×640) | % opaco | veredicto |
|---|---|---|
| `fisura_wave` | 29% | ✅ chibi, estilo del juego |
| `fisura_celebrate` | 33% | ✅ chibi |
| `fisura_point` | 18% | ⚠️ recortada pero **OTRO estilo**: proporciones realistas, colores apagados — no es el personaje del juego |
| `fisura_explain` | **100%** | ❌ **no es una pose: es una ESCENA entera opaca** (callejón con graffiti "CITY SOUL / URBAN DECAY", tacho, y el Fisura con una botella) metida en el retrato de 76×92 — se ve como un thumbnail pegado (capturado en los pasos 2 y 3) |

Además el fallback del retrato cae a SF Symbol `person.fill`
(`TutorialOverlay.swift:421-434`) y la mano que late es el SF
`hand.point.up.left.fill` blanco (`:340`) — los dos violan "sólo fotos del
Fisura / arte del juego". Los prompts de regeneración YA existen:
`Tools/asset-pipeline/prompts/gemini_pro/117_fisura_point.md` y
`118_fisura_explain.md` (más 119/120 ya sanos).

### 2.5 La tarjeta habla el idioma viejo

`TutorialCard` (`TutorialOverlay.swift:368-465`) es pre-rediseño: crema plana
+ borde `PaletteBrown` 3pt + sombra. Cero gramática v3 (pergamino con luz,
tono-sobre-tono, pills caramelo, familia `PanelCard` de `PanelFrames.swift`).
La transición entre pasos es un `.opacity` pelado (`:207`). El botón del
cierre sí usa `ArtButton` (`:397`). El overlay en sí (spotlight `eoFill`
animable, scrim 0.68, markers AX de fondo `:219-249`) está bien construido y
se conserva.

### 2.6 Tutorial y celebraciones se pisan — y hay un deadlock latente

`grep fisuTutorialDone` da 2 hits: el overlay y `RootView`. La cola
(`CelebrationQueue`, `GameState+Celebrations.swift`) **no sabe que el
tutorial existe**. El gate vive en la presentación y es PARCIAL:

- **NO gateadas** (se reproducen con el tutorial arriba): `.boardCelebration`
  (`BoardScene.swift:376`), `.achievements` (`RootView.swift:182`),
  `.towerNotice` (`:147`), `.eventBanner` (`:351`). Consecuencia vista en el
  recorrido: el reveal del primer merge del FTUE (flash + scrim negro 0.72 +
  foto + "¡NUEVO!") se reproduce **debajo del scrim 0.68 del tutorial** — dos
  scrims peleando, el momento estrella del juego semi-invisible, y la
  tarjeta del paso siguiente ya montada encima.
- **El parche existente es mínimo a propósito**: `hidesUIForCelebration &&
  tutorialDone` (`RootView.swift:369-384`) sólo evita que el reveal apague la
  barra que el tutorial está señalando. El comentario mismo documenta que no
  toca la cola.
- **Gateadas con deadlock**: los 5 kinds de hoja (career, skinAward, offline,
  specialDrop, dailyReward) tienen `timeout == nil`
  (`CelebrationQueue.swift:55`). Si uno toma `current` con el tutorial vivo,
  su sheet no se presenta (binding gateado por `tutorialDone`,
  `RootView.swift:294-323`), nadie llama `finish`, el watchdog no aplica → la
  cola ENTERA queda congelada hasta terminar el tutorial. **Ruta viva**: el
  freno del daily sólo cubre el día 1 (`GameState.swift:484-491` marca
  `lastClaimDay` en la instalación fresca); un jugador que abandona el
  tutorial a medias y vuelve al día siguiente dispara `claimDailyIfAvailable()`
  → `.dailyReward` (prioridad 1) toma el turno → congelada. El cohort más
  golpeado es exactamente el que abandonó el tutorial.
- `CelebrationQueueTests` + `CelebrationWiringTests`: **cero** menciones al
  tutorial.

### 2.7 Micro-hallazgos del recorrido (para no re-descubrirlos)

- Los eventos `.ui` (`openedUpgrades`/`openedMap`) **no persisten**: matada la
  app a mitad de tutorial, al volver se rehace el paso (verificado con
  kill+relaunch; los milestones `ftue.*` y `fisuTutorialDone` sí sobreviven).
- **"¡NUEVO!" está hardcodeado en español** (`BoardScene.swift:1140`): en UI
  inglesa también grita ¡NUEVO!.
- Las claves `tutorial.step.*` figuran `"extractionState": "stale"` en el
  xcstrings (la extracción no ve `LocalizedStringKey` dinámicas): no podarlas.
- El paso 0 real cuesta ~25 taps (tapYield 1, primer Fisura 25) más el goteo
  de 0,5/s del inicial: medio minuto de tapeo. Está bien como fricción de
  arranque — no lo "arregles" sin pedido del dueño.
- `ui_badge@2x/@3x` está en el atlas y en `assets_manifest.json:547`,
  **huérfano**, y el comentario de `CountBadge`
  (`GameArtComponents.swift:773-778`) ya lo reserva textualmente para "el
  puntito de 'hay regalos'".
- **No existe la señal "hay logro cobrable"**: `achievementRows` mide los 39
  gatillos en cada lectura (advertencia en `AchievementsView.swift:32-33`).
  La forma barata es la resta de sets
  (`unlockedAchievements − claimedAchievements`), pero `player` es
  `@ObservationIgnored` (`GameState.swift:288`): hay que PUBLICARLA como
  proyección desde `refreshProjections()`.

---

## 3. Lo que NO se toca (decisiones cerradas)

- **La CelebrationQueue como diseño** (turnos sin payloads, dedup, watchdog,
  skip con piso de 0,6 s). "Cada animación por separado, una por una, como
  regla general para TODA la app" es pedido del dueño
  (`Docs/SESION-2026-08-17-cola-de-celebraciones.md`). El tutorial pasa a ser
  **cliente** de esa regla, no una excepción por afuera.
- **La gramática v3 es canon y FisuJobs la referencia visual de todas las
  pantallas** (regla del dueño). El tutorial nuevo la habla, no inventa otra.
- **Los contratos de AX**: markers `tutorial.step`/`tutorial.spotlight` como
  capas de FONDO 1×1 (`TutorialOverlay.swift:219-249` documenta por qué), y
  las trampas 9/9a (un identifier en un contenedor se come a sus hijos; el
  badge NUNCA es un elemento con identifier adentro del label de un botón).
- **`resolveDrop` como único camino de fusión** y el cooldown de 0,8 s.
- **Las claves `ftue.*` y `fisuTutorialDone`**: los saves existentes con el
  tutorial hecho no deben volver a verlo.
- **El ancho de la barra inferior**: 374 ≤ 375 pt en SE
  (`GameArtComponents.swift:1141-1147`). El badge es `.overlay`, jamás un
  hijo del layout.
- **Cero strings hardcodeados**: todo por `Localizable.xcstrings`, es + en,
  voz rioplatense de la casa.

---

## 4. El trabajo, en orden obligatorio

### 4.1 PRIMERO el arbitraje: el tutorial entra a la cola

Sin esto, cualquier guion nuevo hereda las pisadas de hoy.

- `GameState` publica que el tutorial está vivo (proyección, no lectura de
  AppStorage desde la cola), y **la cola decide**: con la fase obligatoria
  corriendo, no se promueve nada que el tutorial no pida — los kinds quedan
  en `pending`, no toman `current`. Eso mata el deadlock de §2.6 por
  construcción: el daily del día 2 espera su turno y aparece al terminar.
  Matá el parche `hidesUIForCelebration && tutorialDone` — con el arbitraje
  bien puesto queda sin trabajo.
- **El reveal del primer merge es EL momento, no un estorbo**: el paso
  "merge" se completa, el overlay del tutorial SE ESCONDE entero (scrim
  incluido), el reveal se reproduce limpio con su propia secuencia, y el
  paso siguiente aparece recién con `celebrationFinished`. Regla dura:
  **nunca dos scrims a la vez, nunca un reveal debajo del scrim del
  tutorial**.
- Tests: `CelebrationWiringTests` suma los casos con tutorial activo (hoy
  cero), incluido el repro del daily día-2-a-medias.

### 4.2 El guion nuevo: fase obligatoria corta + lecciones contextuales

- **Fase obligatoria** (una vez, 2-3 minutos): tap → hire → merge → reveal
  limpio → cierre con `fisura_celebrate` que deja UN objetivo ("fusioná
  hasta el T5 y se abre el piso 2"). Mueren los pasos 3 y 4 actuales (abrir
  hojas por abrirlas).
- **El resto de la app se enseña en lecciones contextuales** de máximo dos
  tiempos (señalar → hacer), disparadas la PRIMERA vez que su condición se
  cumple, y montadas como ítems de la CelebrationQueue (kind nuevo
  `tutorialTip`: prioridad baja, skippable, con timeout). Así el "de a una"
  y el no-pisarse salen gratis del diseño existente.
- La tabla — lección → disparador exacto → a dónde señala:

| lección | disparador (primera vez que…) | señal | destino |
|---|---|---|---|
| Mejoras | hay una mejora PAGABLE | publicar `canAffordAnyUpgrade` en `refreshProjections()` (NO leer `characterUpgradeRows` por frame — es cara, `GameState+Upgrades.swift:83-110`) | tab `hud.upgrades` |
| Ascensor | se desbloquea el 2º piso | publicar `unlockedFloorsCount` (hoy se recalcula inline en 6 lados; `GameState.swift:814-833`) | botón `hud.map` |
| Atajo | `bestHire.affordable == true` post-fase (`GameState.swift:167`) | ya publicada | `hud.quickhire` |
| Pintas | `ownedSkins` deja de estar vacío (`GameState.swift:172`; la skin milestone del piso 2 es el momento natural) | ya publicada | tab `hud.skins` |
| Logros | hay un logro COBRABLE | proyección nueva `hasClaimableAchievements` (§4.3) | tab `hud.settings` → tarjeta `menu.card.achievements` |
| Regalos | primer daily/regalo disponible post-fase | payload ya existente | tab `hud.bonus` |
| Tienda | UNA vez, suave, primera sesión con oferta relevante | — | tab `hud.store` |
| Prestigio | el indicador de prestigio se enciende por primera vez | proyección del indicador existente | botón de prestigio |

- **Regla de oro del gating** (la frase del dueño como criterio de
  aceptación): ninguna lección manda a una pantalla donde EN ESE MOMENTO no
  hay nada que hacer.
- **Guía adentro de las hojas**: en el paso hire, la instrucción tiene que
  vivir TAMBIÉN dentro de FisuJobs (banda compacta o spotlight propio de la
  hoja — mecanismo a elección; la hoja se presenta encima del overlay y eso
  no cambia, `TutorialOverlay.swift:62-73`). La fila verde de affordable
  ayuda pero no es una instrucción.
- **Persistencia por lección** (flags estilo `ftue.*`, versionables): los
  eventos `.ui` que hoy se pierden al matar la app mueren con este guion —
  nada se rehace al reanudar.

### 4.3 El puntito rojo (`ui_badge`): logros cobrables

- Proyección nueva publicada desde `refreshProjections()`
  (`GameState.swift:735-812`): resta de sets
  `unlockedAchievements − claimedAchievements`, re-evaluada también al
  bumpear `effectsVersion` (que ya escribe `claimAchievement`,
  `GameState+Achievements.swift:282`). **NO** derivarla de `achievementRows`.
- Dos superficies, mismo componente: overlay `.topTrailing` sobre el plato
  del tab Menú (`GameTabButton`, ZStack `GameArtComponents.swift:1157-1161`)
  y sobre la tarjeta `menu.card.achievements` (`MenuView.swift:131-137`).
  `GameIcon(artKey: "ui_badge")` con fallback vectorial (círculo rojo, borde
  ink). Aparece cuando hay cobrable, muere al cobrar el último.
- ⚠️ Medí el % de píxeles opacos del `ui_badge@2x` antes de estrenarlo (bug
  #6 del pipeline: rellenos comidos): si salió hueco, va el vectorial y el
  PNG se regenera.
- AX: `accessibilityValue` en el botón existente (trampa 9a: nada de
  elementos nuevos adentro del label).
- **La lección de Logros enseña la dinámica completa**: aparece el badge en
  el tab Menú → el jugador entra → la tarjeta Achievements también tiene el
  puntito → cobra → el badge muere. Ese circuito ES la lección; el tutorial
  la dispara la primera vez que `hasClaimableAchievements` pasa a true.

### 4.4 Sólo fotos del Fisura, y las cuatro sanas

- **Regenerar** `117_fisura_point` (pose SEÑALANDO con el dedo, chibi
  idéntico a wave/celebrate, `referencia: heroes/approved/fisura.png`, fondo
  blanco puro, prompt en ASCII) y `118_fisura_explain` (pose explicando con
  las manos abiertas, RECORTE de personaje, sin escena, sin botella). Los
  `.md` vuelven a `estado: pendiente`; el batch con la receta del HANDOFF §8
  (máquina quieta, timeout ≥250 s, medir opacidad post-batch).
- **Mientras el arte no llegue, el guion usa sólo `wave` y `celebrate`.**
- Muere el fallback a `person.fill` (`TutorialOverlay.swift:427`): sin atlas
  se cae a `wave`, nunca a un SF Symbol.
- **La mano deja de ser un SF Symbol**: mano vectorial de la familia del
  juego (trazo ink, el guante sin dedos del Fisura), en `GameIcons.swift`
  junto a los demás `Vector*`.
- Poses por momento: `wave` saluda (arranque), `point` señala (espejada si
  el spotlight queda del lado contrario), `explain` explica conceptos,
  `celebrate` cierra.

### 4.5 La tarjeta y el overlay, en v3

- `TutorialCard` se reconstruye con la gramática v3 (`PanelFrames.swift` es
  el vocabulario: pergamino con luz, bordes tono-sobre-tono, dots como pills
  caramelo, botones de la familia del juego). El retrato crece (≥96 pt) y la
  pose pisa el borde de la tarjeta como en las referencias, sin marquito.
- Transición entre pasos: pop con spring (como el `keyframeAnimator` de los
  tabs), no el `.opacity` pelado. El spotlight ya anima su forma
  (`animatableData`) — se conserva. Reduce Motion colapsa todo (regla
  existente, `:310-312`).
- El scrim 0.68 queda SOLO para la fase obligatoria. Las lecciones
  contextuales usan coach-mark liviano (globo + anillo, sin scrim total):
  una lección nunca congela el juego.
- "¡NUEVO!" del reveal sale del hardcode (`BoardScene.swift:1140`) a
  `Localizable.xcstrings`, es + en.

### 4.6 Verificación

- Suites con la receta del HANDOFF §6: EconomyKit → unit → UI, simulador
  propio por UDID, `-parallel-testing-enabled NO`, unit ANTES que UI, cero
  warnings, y el simulador se borra al final.
- `TutorialUITests` se reescribe para el guion nuevo (los fixtures
  `--uitest-coins`, `--uitest-achievements`, `--uitest-skins` ya existen;
  sumá el que falte por lección). `CelebrationWiringTests` con los casos de
  §4.1.
- **Recorrido manual obligatorio en fresh install, en es Y en en**: fase
  entera con el reveal limpio, día 2 simulado sin deadlock, cada lección
  disparando en su momento (y NO antes), badge naciendo y muriendo, Reduce
  Motion, y un pase en SE (374 pt) para el badge y la tarjeta.

---

## 5. Definición de hecho

- [ ] La fase obligatoria es tap → hire → merge → reveal limpio → cierre, en
      2-3 minutos, con guía visible DENTRO de FisuJobs en el paso hire.
- [ ] El reveal del primer merge se ve entero y limpio: cero scrims
      superpuestos, cero tarjetas del tutorial encima (a ojo y con test).
- [ ] La cola arbitra: con el tutorial vivo nada toma `current` sin permiso,
      y el repro del daily día-2-a-medias pasa en verde.
- [ ] Cada pantalla del juego tiene su lección contextual, y ninguna dispara
      antes de que haya algo que HACER ahí (la tabla de §4.2 completa).
- [ ] El badge rojo vive en el tab Menú y en la tarjeta de Logros, nace con
      el primer cobrable, muere con el último, y su lección lo enseña.
- [ ] El tutorial usa SOLO poses del Fisura, las cuatro en el estilo chibi
      del juego (117 y 118 regeneradas e integradas con opacidad sana), la
      mano es vectorial de la casa y no queda ningún SF Symbol visible.
- [ ] La tarjeta habla la gramática v3 y las transiciones son de juego, no
      de formulario.
- [ ] "¡NUEVO!" localizado; cero strings nuevos hardcodeados; es + en.
- [ ] Nada se rehace al matar y reabrir la app a mitad de guion.
- [ ] Suites verdes con la receta §6 y el recorrido manual de §4.6 hecho y
      anotado.
- [ ] Cierre con el sistema de handoffs (`~/Desktop/skills/documentation`):
      doc de sesión + handoff efímero + el general actualizado.

---

## 6. Decisiones que este prompt ya toma (no re-preguntar) — y las del dueño

**Tomadas acá, con base en el pedido textual:**

| Decisión | Por qué |
|---|---|
| La fase obligatoria termina tras el reveal del primer merge | "pacing es muy importante": los pasos de abrir-hojas-vacías son los que lo rompen hoy |
| Las lecciones contextuales viajan por la CelebrationQueue | es la regla de "de a una" que el dueño ya pidió para toda la app; reusa dedup, skip y watchdog en vez de inventar un segundo árbitro |
| Con el tutorial vivo, los kinds de hoja quedan en `pending` (no se presentan ni se pierden) | mata el deadlock sin excepciones por kind |
| Lecciones con coach-mark liviano, sin scrim total | "high end": el juego nunca se congela por un tip |

**Del dueño, si el que ejecuta duda** (responder antes de implementar esa
parte, no bloquea el resto): ¿la lección de Tienda va (recomendado: una sola
vez, suave) o se saca? ¿el prestigio se enseña apenas se enciende el
indicador o más tarde?
