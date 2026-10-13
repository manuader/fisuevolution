# Sesión 2026-10-12 — E14: las correcciones del dueño antes de la App Store

Sesión del dueño (en vivo, en paralelo al relevo 49). No hay código: la salida es la spec de E14 (C1–C31),
el plan por tareas con sus decisiones, los mockups aprobados y el arte de E14 en producción.

## Qué quedó

- **Spec:** `Docs/PLAN-v2-E14-correcciones.md`. Las 31 correcciones, cada una con lo que dijo el dueño, la causa
  verificada en el código, qué hacer y el criterio de «listo».
- **Plan:** `Docs/superpowers/plans/2026-10-12-v2-e14-correcciones-dueno.md`. Incluye:
  - 29 tareas (T0–T28);
  - las decisiones D1–D13;
  - los gates G1–G4;
  - 9 olas.
- **El tablero:** E14 está cargada en `tasks.md` (§2 nota, §4.0, §5 «E14», §6 «Gates de E14», §7) con
  **prioridad absoluta** (D9).
- **Mockups aprobados (G1 ✅):** `Docs/correcciones-v2/mockups/fisu-e14.html`, 21 pantallas con el arte
  real. También están publicados como página privada del dueño. El dueño los aprobó todos con una salvedad:
  «algunos no se ven exactamente como en el juego, pero la idea general está bien». De ahí sale **D13**: el
  mockup fija disposición, jerarquía y flujo, y la apariencia la dan los componentes reales.
- **Referencias del dueño:** capturas suyas y de Cow Evolution en `Docs/correcciones-v2/`.
- **Arte de E14:** el proyecto `automatic-image-generation/projects/fisu-v2-premios` tiene 27 prompts de
  imagen y 11 de video.
  - Los 11 videos están **generados** (Kling v3.0, 720×720, 24 fps, 94,5 créditos, commit `ef16ceb` allá):
    8 ok y 3 dudosos.
  - Las imágenes se están generando con Gemini, vía `correr-batch-gemini.command` y el supervisor.

## Lo que se encontró en el código (las causas que el dueño no veía)

Cada una está con su archivo en la spec. Acá van las que cambian el diseño:

- **El vendedor «aparece siempre» (C5)** porque tiene un **carril propio**:
  - su carril trae una visita cada 180 s ± 30, con `dailyCap` 20;
  - los otros 17 visitantes comparten otro carril, una visita cada 240–360 s;
  - el carril principal sortea **guiones** por peso, no visitantes: quien tiene dos guiones pesa el doble,
    y `antiRepeat` también mira guiones.

  Queda una **hipótesis sin medir**: con un solo lugar en escena, el carril principal choca con el vendedor
  y cae en `retrySoon`. Eso explicaría que el dueño no haya visto nunca al turista ni a la vecina. T6 lo
  mide con el simulador.
- **El fondo «se ve peor quieto» (C1):** el `LoopingVideoNode` del fondo (1024²) se monta encima de la foto
  (2048²) y sólo se prende con el piso quieto.
- **Ventanas negras en el ascensor (C7):** `ElevatorCabinArt.resolve` le da prioridad al video sobre los PNG.
  `cabina_cerrada.png` tiene las ventanas con alfa 0 (medido), pero el video tiene esas ventanas en gris
  opaco. La hipótesis principal es que durante el viaje queda el último cuadro del video.
- **La imagen que se comparte es un SF Symbol (C23):** `ShareCardContent` dibuja `Image(systemName:)` con
  el `spritePlaceholder` del tier. Lo que llega a las redes es un ícono de sistema.
- **El Paquete de la Aduana trae un empleado gratis (C28):** `PackageRoller` sortea en una ventana de 4
  tiers, pesada por «Mejor proveedor», y el paquete no se gasta si no hay lugar. Nada de eso se le dice al
  jugador.
- **La caja y el colchón (C10)** miden 0,62 celdas (`sideRatio`) y se apoyan en la línea baja de
  `StageLayout`. Quedan en x = 31 % y 69 %, justo donde están la ficha del Fisura y el botón de reencarnar.
- **UI genérica (C19):** en `FisuEvolution/UI` hay **124 SF Symbols** (44 `systemName:` + 80
  `systemImage:`) y las tres ofertas usan símbolos de sistema.
- **Tiers 7 y 8 (C17):** la economía es posicional (`tapYield`, `passiveYieldPerInstance` y
  `passiveUnlockCost` van por escalón). Intercambiar personajes sin migrar el save movería la producción
  de un jugador de la v1. Por eso la migración es por posición y las skins siguen al personaje.
- **Lo que se ahorra al quitar los personajes base animados (C22):** son 43 clips en los packs
  `anim-piso-*`, 8,6 MB. Los 10 especiales siguen animados.

## Decisiones (D1–D13)

Están en el plan y en `tasks.md` §7. Las que costó cerrar:

- **D4, el pedido de empleado:** el dueño pidió ver las dos opciones (en el horizonte, o abajo a la
  izquierda como el alien de Cow Evolution) y después aprobó **todos** los mockups sin elegir una. Se tomó
  la A, que era la recomendada y es coherente con C2 (nada abajo). La B queda en el mockup por si al verla
  en el juego la prefiere.
- **D5, compartir en todos:** el dueño eligió que la card con «¡Compartir!» salga también en los tres
  primeros personajes del tutorial. Era lo contrario del default propuesto.
- **D13:** ver «Qué quedó».

## Lo que costó tiempo (y no se deduce del código)

- **Esta sesión le cambió la rama al worktree de `version-2` de los relevos.** Hice
  `git switch -c v2/e14-correcciones-dueno` en `.claude/worktrees.nosync/version-2`, sin saber que es **el
  mismo directorio** que `.claude/worktrees/version-2`: `worktrees.nosync` apunta a `worktrees`. El relevo
  49 lo detectó en su journal. Se arregló: ese worktree volvió a `version-2` en `cc5f82c3` y E14 sigue en
  su propio worktree (`.claude/worktrees/v2-e14-dueno`). Va como trampa en el HANDOFF §7.
- **`docs/` y `Docs/` son la misma carpeta** (el sistema de archivos no distingue mayúsculas, pero git sí).
  El plan se escribió como `docs/superpowers/...` y el `git add` con esa ruta no agregó nada. Quedó afuera
  del commit hasta que `git status` lo mostró como `Docs/superpowers/...` sin seguir. Siempre `Docs/`.
- **«El script de Gemini está parado»:** no estaba parado; nunca se había lanzado. Sólo se había abierto
  el Chrome aislado con `--launch`. El batch arranca con
  `open projects/fisu-v2-premios/correr-batch-gemini.command`, y el modelo (Flash) se elige a mano en ese
  Chrome: el runner no lo controla.
- **Prompts de Gemini en ASCII:** tres prompts de video tenían raya larga (—). Se cambiaron por «-» antes de
  lanzar; las tildes y las rayas en el cuerpo pierden caracteres al tipear (memoria
  `gemini-batch-desde-agente`).
- **Kling no baja de 3 s:** las tres sacudidas (pedidas de 1 s) y `ruleta_premio` (pedido de 2 s) salieron
  de 3 s. T3 las recorta al integrar. Higgsfield además ofrecía presets («IN THE DARK», «Earth zoom out»)
  que frenaban el envío: hubo que rechazarlos.

## Lo que se dejó afuera a propósito

- **No se escribió código:** el dueño pidió el plan listo para el relevo, no la implementación en esta
  sesión.
- **4K de fondos:** no existe una fuente 4K (las fotos son 2048, reescaladas desde originales de 1254). Por
  D1 quedan en 2048.
- **Los eventos que llevan a la Tienda no traen descuento (D7).** Si algún día se quiere uno, se engancha a
  `offers.json`, no al evento.
- **El arte de los mockups no es el arte final:** lo que lleva la etiqueta «arte nuevo» se ve con
  reemplazos. Los PNG de los mockups (`Docs/correcciones-v2/mockups/a/`) son copias achicadas del juego y
  no se usan como assets.

## Después, en la misma sesión: el arte, el boost y Supabase

- **Arte de E14 aprobado:**
  - las 27 imágenes y 10 de los 11 videos;
  - `colchon_abre` se regeneró con una explosión de dinero, con billetes sin verde por el croma (4,5 créditos);
  - en total se gastaron 99 créditos de Higgsfield.
- **C32, el exploit del boost por video (E14-T29, va primero).** `activateBoostFromAd` restauraba el cooldown
  viejo en un `defer`, así que el video se repetía sin fin. Y `BoostManager.activate` agrega un modifier en cada
  activación, que `ModifierMath.factor` multiplica: el Turbo ×3 con tres videos daba ×27.
- **E8e T10a–T10f salteadas** por C22: los personajes base quedan estáticos.
- **E12 T16, Supabase desplegado con el MCP.** El detalle está en `supabase/README.md`, «El despliegue real».
  Dos cosas que costaron:
  - el secreto del cron se generó dentro de la base y la función lo lee del Vault, porque cargar un secreto a
    mano en el panel era el único paso que pedía al dueño;
  - las versiones de las migraciones se renombraron a las de los archivos para que la CLI no las reaplique.

  La clave publicable `sb_publishable_…` pasa `verify_jwt = true` (medido con curl). La prueba de humo contra el
  proyecto real quedó verde y el oráculo `tarea` también (EK 879 · unit 37).
