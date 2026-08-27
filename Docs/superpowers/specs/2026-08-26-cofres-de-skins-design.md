# Cofres de skins — diseño

**Fecha**: 2026-08-26 · **Rama**: `feat/cofres-de-skins` (desde `origin/main` @ `0df3cba`)

## 1. Qué se pidió

Cambiar cómo se obtienen las skins e introducir **cofres con premio aleatorio**. Cada
cierto tiempo (pisos desbloqueados) te ganás uno, y además podés mirar un video para
abrir otro. La bolsa son las skins "sin criterio de obtención claro": ni las pagas ni
las de oro. Cada cofre desbloquea **a lo sumo una** skin. La animación tiene que ser
entretenida e interactiva —"es lo que más garpa del sistema de cofres"— al estilo
Clash Royale pero con la estética de FisuEvolution, y coherente con las demás
animaciones del juego.

### Las siete decisiones del dueño (2026-08-26)

1. Las 41 skins de piso **pasan a ser exclusivas del cofre**: dejan de otorgarse al
   llegar a un piso.
2. **Un cofre temprano**, en el tutorial, para poder enseñar la mecánica ahí.
3. **Rareza + sin repetir dentro de ella.**
4. Si la rareza sorteada está agotada, **sube** a la siguiente con stock.
5. Las **cuatro** fuentes: cada 2 pisos, video, día 7 y reencarnación.
6. El primero se abre solo; **el resto se guardan** y los abre el jugador.
7. Se mantiene la palabra **"cofre"** para las skins y **se renombran** los tres usos
   que hoy significan plata. Las estrellas van **dibujadas** (PNG), no en código.

## 2. La bolsa: 41 skins en 4 rarezas

De las 131 skins del catálogo, la bolsa son las **41** que hoy llevan `floorReached`.
Quedan afuera por criterio del dueño: las 43 de `oro` (maxear las siete mejoras), las
43 de `diamante` y las 2 sueltas de IAP (`mundialista`, `parrillero`), y las 2 de
reencarnación (`second_life`, `genesis`), que conservan su condición.

La bolsa cubre exactamente los tiers **T2 a T36**: el Fisura (T1) y el Dios (T37) son
los dos personajes cuyas skins no son de piso.

La rareza sale del piso donde **vive el personaje** —lo que el jugador percibe— y no
del `floorReached`, que apunta un piso más arriba:

| Rareza | Pisos | # | Color (paleta lockeada) | Peso |
|---|---|---:|---|---:|
| Común | `alley` + `urban` | 7 | verde `#6BCB77` | 55 |
| Rara | `corporate` + `luxury` | 14 | azul `#4D96FF` | 28 |
| Épica | `island` + `moon` + `mars` | 12 | rosa `#FF4D6D` | 12 |
| Legendaria | `solar` + `galaxy` | 8 | amarillo `#FFD93D` | 5 |

⚠️ **La rareza "rara" tiene 14 y no 8 porque el piso corporativo tiene diez
personajes**: la bifurcación de carrera mete cuatro `junior` en T11 y cuatro `senior`
en T12. Es el único piso que no tiene cuatro.

### Cómo se declara

Las 41 entradas de `skins.json` cambian `"floorReached": "<piso>"` por
`"chestRarity": "<rareza>"`.

Esto es lo que hace que **`SkinMilestones.newlyUnlocked` deje de otorgarlas sin
tocarle una línea**: `Entry.isMilestone` se calcula como
`floorReached != nil || reincarnations != nil || upgradesMaxed == true`, así que sin
`floorReached` la entrada cae sola fuera del evaluador. No hay forma de que una skin
se regale por las dos vías, porque la segunda vía deja de existir por construcción.

`SkinsConfig.Entry` suma `chestRarity: String?` y `validate` exige que sea una de las
cuatro. Una entrada con `chestRarity` **y** un campo de milestone es un error de
validación: son excluyentes.

## 3. El sorteo — `ChestRoller`

Tipo puro y `Sendable` en EconomyKit, con RNG inyectado (mismo patrón que
`special_roll` en `ContentSystems`). No conoce UI ni `GameState`.

```
roll(owned: Set<String>, config: ChestsConfig, skins: SkinsConfig,
     floor: Rarity?, rng: inout RandomNumberGenerator) -> Outcome
```

1. Sortea una rareza por peso. Si el cofre tiene **piso** (`floor`), el sorteo se
   restringe a esa rareza y las superiores, con sus pesos relativos.
2. Si esa rareza no tiene skins sin poseer, **promociona hacia arriba** a la primera
   que tenga stock. Si no hay ninguna arriba, **baja** a la primera con stock.
3. Elige una skin al azar entre las no poseídas de la rareza resultante.
4. Si **todas** las rarezas están agotadas, el resultado es `.coins(amount)`.

El color se anuncia **después** del paso 2, así que la promoción nunca hace que la
animación mienta.

### Por qué promociona en vez de pagar plata

Medido sobre la bolsa real: las 7 comunes se agotan cerca del cofre 12. Con la regla
literal de "rareza completa = plata", desde ahí el **55 % de los cofres pagaría plata
con 34 skins todavía sin sacar**, y completar costaría ~90 cofres. Con promoción:

- **Todo cofre abierto antes de completar da una skin nueva** → 41 cofres exactos.
- Como todo promociona hacia arriba, **lo último que queda son las legendarias**: la
  colección termina en crescendo en vez de en repetidas.

### El pago cuando ya está todo

`economy.passiveUnlockCost(forTier: run.maxTierReached) × completedPayoutFactor`, la
misma fórmula que usa el día 7 cuando ya tenés los diez specials. Factor **6,0** para
el cofre normal y **12,0** para el de reencarnación.

## 4. Las fuentes

| Fuente | Cuándo | Piso de rareza | Por partida | Total (~9 partidas) |
|---|---|---|---:|---:|
| Bienvenida | al cerrar la fase obligatoria del tutorial | fijo: Trapito | 1, sólo la 1ª | 1 |
| Torre | cada 2 pisos desbloqueados (2·4·6·8·10) | — | 5 | 45 |
| Reencarnación | al confirmar el prestigio | **épica** | — | 8 |
| Día 7 | si ya tenés los 10 specials | — | ~1/semana | ~2 |
| Video | rewarded con cooldown de 4 h | — | ~2-4/día | ~25 |
| | | | | **≈80** |

Con 41 para completar, **la colección se cierra cerca de la mitad de la partida
larga** y de ahí en adelante los cofres pagan plata. El freno, si hace falta, es el
`cooldownSeconds` del video: pasarlo de 4 h a 8 h saca ~12 cofres.

El contador de la torre vive en `run` y **se reinicia al reencarnar** (`run = .fresh`),
que es lo que hace que volver a subir la torre siga pagando — alineado con lo que
busca el rebalance de pacing.

⚠️ **El día 7 ya tiene dueño.** Hoy sortea un special de los 10 y sólo paga plata
cuando los tenés todos (`ContentSystems.swift:384`). El cofre **no lo reemplaza**: se
mete como segundo escalón, `special → cofre → plata`.

⚠️ **El video no necesita infraestructura nueva.** Se da de alta como un `reward` más
en `rewarded_ads.json` con `effectType: "skinChest"`. La fila en Regalos, el cooldown,
el spinner y el `rewardedActivations` del save aparecen solos porque `rewardRows` mapea
sobre el config. Hay que agregar el `case` en dos `switch` (`applyRewardedReward` y
`rewardText`) — los dos son exhaustivos, así que el compilador los señala.

## 5. El cofre de bienvenida

Cae al cerrar la fase obligatoria del tutorial (tap → contratar → fusionar), que es
cuando `tutorialPhaseFinished()` levanta la restricción de la cola. **Se abre solo** y
su premio **no es aleatorio: es la pinta del Trapito**, el personaje que el jugador
acaba de fusionar.

⚠️ **Corregido el 2026-08-27, y el error vale anotarlo.** Este spec decía "la pinta del
Cartonero" y estaba mal: `homeless.mergesInto == "trapito"`, así que el tutorial deja al
jugador con **El Trapito (T2)**, no con el Cartonero (T4). Se estaba regalando la pinta de
un personaje que el jugador todavía no conoció, y la carta decía literal "para tu Cartonero".
Lo cazó el implementador de la tarea 11 mirando los datos en vez de creerle al spec. El
premio es `naranjita`, la pinta común del Trapito. La lección se enseña sola, y el botón "Ponérsela" cierra el
circuito.

Reemplaza el disparador de la lección `.tutorialTip / .skins`, que hoy es "la skin de
milestone del piso 2" y con este cambio deja de existir. La lección sobrevive
apuntando a la pestaña de Pintas después del cofre.

Se otorga **una vez por save** (bandera en `meta`), no una por partida.

## 6. Estado y persistencia — save v5

| Campo | Dónde | Para qué |
|---|---|---|
| `chestsPending: Int` | `meta` | cofres sin abrir; sobrevive la reencarnación |
| `floorChestsAwarded: Int` | `run` | cuántos dio la torre en ESTA partida |
| `welcomeChestGiven: Bool` | `meta` | el del tutorial, una vez por save |

`PlayerState` decodifica explícito, así que campos nuevos **piden bump de schema**.
`SaveMigrator` suma `migrateV4toV5`, que arranca los tres en cero.

⚠️ **El mismo bump arregla la deuda declarada de las skins de oro** (decisión del
dueño, 2026-08-26). Hoy un save anterior al rebalance con `crit` entre 10 y 24 cuenta
como maxeado por el `>=` de `awardEligibleMilestoneSkins` y se lleva las 43 doradas sin
haberlas ganado — está documentado en el HANDOFF como aceptado *justamente porque
pedía un v5*. La migración marca esos saves y no les acredita las doradas.

## 7. La cola de celebraciones

`CelebrationKind` suma **`.chestOpening`**:

- **prioridad 4**, junto a `.skinAward` y `.specialDrop`: el reveal del tablero
  (prioridad 3) que otorgó el cofre se ve entero antes.
- **`timeout: nil`**: lo cierra el jugador, como los otros sheets de premio. Por lo
  tanto `isSkippable == false` — el salteo *interno* de la animación es asunto de la
  vista, no de la cola.
- **Apaga la UI**: `publishCelebration()` pasa de
  `kind == .boardCelebration && boardCelebrationShowsSomethingNew` a incluir
  `|| kind == .chestOpening`.
- `syncCelebrations()` encola cuando hay payload, igual que los otros doce.
- Durante la fase obligatoria del tutorial la restricción lo deja en `pending` y
  desfila apenas termina — que es exactamente lo que se quiere para el de bienvenida.

## 8. Dónde vive el cofre guardado

- **Puntito** (`NotificationBadge`) en la pestaña de Regalos cuando `chestsPending > 0`
  — el mismo circuito que ya enseña el tutorial para los logros.
- **Primera sección de Regalos**: una `GameCard` destacada con el cofre dibujado, el
  contador y "Abrir". Arriba del calendario.

## 9. La animación

Overlay a pantalla completa en el `ZStack` de `RootView`, telón al 55 %. **No es un
`sheet`**: los otros dos overlays no-modales del juego (`towerNotice`,
`achievementToast`) ya viven así, y un sheet trae un gesto de arrastre que puede matar
la animación por la mitad.

| # | Latido | Input | Qué pasa | Haptic |
|---|---|---|---|---|
| 0 | Llegada | — | El cofre cae, rebota y aplasta al aterrizar. Detrás, `fx_burst_rays` en crema, girando lento. | `.merge` |
| 1 | Forzar (1/3) | tap | Sacudida ±5°, el candado se raja, saltan 4 `fx_star` chicas. | `.merge` |
| 2 | Forzar (2/3) | tap | Sacudida ±9°, `ui_chest_cracked`, 8 estrellas. **Los rayos se tiñen del color de la rareza y aceleran.** | `.purchase` |
| 3 | Forzar (3/3) | tap | Sacudida ±14°, el cofre se hincha, la luz se escapa por las juntas. | `.merge` |
| 4 | Estallido | — (0,4 s) | Flash blanco de 80 ms. `ui_chest_lid` sale volando girando. ~30 estrellas y chispitas con gravedad. Queda `ui_chest_open`. | `.evolution` |
| 5 | La carta vuela | — (0,5 s) | Una carta boca abajo sale del cofre, gira y aterriza grande en el centro. El cofre queda chico abajo. | — |
| 6 | Darla vuelta | tap | Flip 3D de 0,45 s. Del otro lado, la skin en grande sobre la tarjeta amarilla. Segunda ráfaga. | `.evolution` |
| 7 | Reposo | — | Cinta de rareza, nombre de la pinta, personaje. "Ponérsela" / "Después". | — |

Cuatro toques. Si el jugador no toca, cada latido se dispara solo a los **1,2 s**:
nadie queda trabado, pero el que participa va más rápido.

**Si el cofre paga plata**, los latidos 0-4 son idénticos —incluida la rareza, que
sigue decidiendo el color— y en el 5 vuela una moneda gigante en vez de la carta. Que
el principio sea igual es a propósito: si la animación delatara el resultado se pierde
la sorpresa, que es el punto de todo el sistema.

### Reglas del design system que la animación respeta

De `GameArtComponents.swift:9-20`, y no son opcionales:

- **Ningún `repeatForever` incondicional**: el respiro del cofre y el giro de los rayos
  viven sólo mientras el overlay está en pantalla, como el pulso de la manito del
  tutorial (`TutorialOverlay.swift:371`).
- **Todo se apaga con `accessibilityReduceMotion`**, y apagado tiene que dejar la
  pantalla en su estado **FINAL**, no en el inicial. Con Reduce Motion: un solo toque,
  sin sacudidas, la carta ya dada vuelta.
- **Ningún contenedor lleva `accessibilityIdentifier`** (trampa 9a-bis): el id va en el
  control real. Los controles del cofre son el área tappable, "Ponérsela" y "Después".
- Los rebotes usan los mismos `SpringKeyframe(spring: .bouncy)` del bounce de las
  pestañas y del `QuickHireButton`.

### La carta

Es **la misma carta de `SpecialDropView`** —`PanelCard` + `PanelTitleBanner` +
`GameCard` amarilla con el retrato de 168 pt— que el dueño ya pidió que muestre la
skin en grande. El **dorso no se genera**: se arma con el `PanelCard` de madera y el
`GiftBowOrnament`, que es material propio del juego y sale más coherente que un PNG
nuevo.

## 10. Los assets — 7 PNGs

| Key | Qué es |
|---|---|
| `ui_chest_closed` | Cofre de madera cerrado, herrajes y candado dorados, 3/4. Sirve de icono en Regalos y en el puntito. |
| `ui_chest_cracked` | El mismo con el candado rajado y la tapa despegada (toque 2). |
| `ui_chest_open` | Abierto, sin tapa, boca encendida. |
| `ui_chest_lid` | La tapa suelta, para que vuele en el latido 4. |
| `fx_star` | Estrella de 5 puntas gorda, contorno negro parejo, en crema/blanco **para poder teñirla** de los 4 colores. |
| `fx_sparkle` | Chispita de 4 puntas, más chica, mismo criterio. |
| `fx_burst_rays` | Sol de rayos planos que gira detrás del cofre. |

**Un solo cofre, no cuatro por rareza**: la rareza es sorpresa hasta que se abre, así
que un cofre distinto por color la delataría antes de tiempo.

Pipeline de siempre: prompts en **ASCII puro** (trampa de las tildes), paleta lockeada,
`--ref-threshold 1.5`, `batch_uno_por_uno.py` con `--retries 0`, timeout ≥ 250 s. Alta
en `prompts.json` (`assetKey`, `category`, `prompt`) **antes** de generar, o
`process_dropbox.py` los deja como "NOMBRE DESCONOCIDO". Al integrar se stagean **dos
lugares**: el atlas y `dropbox/procesadas/`.

⚠️ Mientras el runner tipea en Chrome, **la sesión de Claude no puede trabajar en
paralelo**: la propia app le roba el foco y el batch aborta.

## 11. El renombre de "cofre"

| Clave | Hoy | Pasa a |
|---|---|---|
| `bonus.effect.chest %@` | "Un cofre de plata %@, cada vez" | `bonus.effect.payout` — "Una picada de plata %@, cada vez" |
| `gifts.chest %@` | "¡Cofre! +%@" | `gifts.payout` — "¡Picada! +%@" |
| `career.reward.chest %@` | "Cofre de bienvenida: %@ de plata" | `career.reward.welcome` — "Bienvenida: %@ de plata" |
| `gifts.daily.chest` | "Cofre" (día 7) | `gifts.daily.surprise` — "Sorpresa" |

Y el `case periodicChest` de `BoostsConfig.EffectType` pasa a `periodicPayout`, con su
`boosts.json`. Las claves nuevas van **a mano** en `Localizable.xcstrings`, es+en.

## 12. Un arreglo que este sistema destapa

`CustomizationView` muestra sólo personajes de `run.seenTypes`, **que se resetea al
reencarnar**. Hoy casi no se nota; con cofres vas a tener la pinta del Emperador
Cósmico a los veinte minutos y no vas a poder verla. El carrusel pasa a mostrar
`seenTypes` **∪ los personajes de los que tenés alguna pinta**.

Es chico, está en el archivo que se toca igual, y sin él el premio del cofre puede
volverse invisible — que es peor que no darlo.

## 13. Contratos de test

- **`ChestRoller`** con RNG inyectado: sorteo normal; promoción hacia arriba con la
  rareza agotada; promoción hacia abajo cuando no hay nada arriba; `.coins` con todo
  agotado; el piso de rareza del cofre de prestigio; y **nunca devuelve una poseída**.
- **La doble vía cerrada**: `SkinMilestones.newlyUnlocked` no otorga ninguna de las 41,
  con un estado que tiene los diez pisos desbloqueados. Es el test de regresión del
  cambio de `skins.json`.
- **Las fuentes**: la torre da uno cada dos pisos y **no** vuelve a darlo al
  re-desbloquear el mismo piso; reencarnar reinicia el contador; el de bienvenida se da
  una sola vez por save.
- **Migración v5**: los tres campos arrancan en cero, y un save v4 con `crit` entre 10
  y 24 **no** se lleva las doradas. ⚠️ El fixture tiene que usar valores que no sean
  punto fijo de la migración — es la trampa que ya dejó verde un test de migración
  borrado (HANDOFF §7, "un test puede cambiar de significado y quedar verde").
- **La cola**: `.chestOpening` no toma el turno mientras corre `.boardCelebration`;
  apaga la UI; la restricción del tutorial lo retiene y lo suelta al terminar la fase.
- **El renombre**: ninguna referencia a las cuatro claves viejas queda en el árbol.

## 14. Lo que NO entra

- **Sin timers de desbloqueo** (Clash Royale). El juego ya tiene cooldowns en Regalos;
  un tercer reloj es ruido, y acá el cofre no monetiza.
- **Sin "near-miss"** (mostrar algo raro y aterrizar en algo común). Es un mecanismo de
  casino y engaña al jugador.
- **Sin cofres pagos ni moneda de cofres.** El único IAP de skins sigue siendo el
  bundle de diamante.
- **Sin arte de cofre por rareza.** Delataría el premio.
