# Sesión 2026-08-21 (cierre) — El merge del rebalance a main, y la manito de vuelta

> Ejecuta `Docs/PROMPT-merge-con-rebalance-pacing.md` (escrito por la sesión
> del rebalance) desde el lado de main. Pedido textual del dueño, además del
> merge: «no rompas nada de lo que hizo el otro agente. seguramente tengas que
> modificar el tutorial. me gustaba mas el simbolo de manito apretando el boton
> que estaba antes. volve a poner eso».

## El merge en sí: trivial por construcción, y no es casualidad

`fix/rebalance-pacing` ya había mergeado **main al día adentro suyo**
(`9ac8e0d`: main `dc4c7ae`, el tutorial high-end completo) y verificado el
árbol combinado. Con eso, `git merge-base main fix/rebalance-pacing` == main:
el merge a main (`9efc8f7`, `--no-ff`) no podía conflictuar y no conflictuó.
La resolución difícil —los dos lados tocando `BestHireTests`, el HANDOFF a
cuatro manos— ya la había hecho la otra sesión; este lado sólo tenía que
**verificar sobre el árbol final** y no deshacer nada.

## Lo que el tutorial necesitó del rebalance: revisión, cero cambios

El aviso del dueño («seguramente tengas que modificar el tutorial») se
verificó punto por punto y el tutorial salió indemne — porque la otra sesión
ya había integrado main y dejado sus contratos en pie:

- Los anchors nuevos (`.quickHire`, `.prestige`) siguen puestos en `RootView`;
  el `QuickHireButton` del rebalance documenta a propósito que él no lleva
  ancla (la lección del atajo señala DESDE afuera).
- `canAffordAnyUpgrade` sigue publicada y su base (costos de mejoras por
  personaje en monedas) no cambió de moneda con el rebalance.
- El paso del cierre («fusioná hasta el T5 y se abre el piso 2») sigue siendo
  cierto: el rebalance no tocó `floors[]` ni la cobertura del callejón.
- La fase (tap → contratar a 25 → fusionar) no toca ningún knob rebalanceado:
  el primer Fisura a 25 es la decisión del dueño que las DOS sesiones
  respetaron.
- La lección del atajo quedó **mejor** que antes del merge: `bestHire` ahora
  vende el tier base del piso, así que «contratá al mejor que puedas pagar»
  enseña la regla nueva sin cambiar una palabra.

## La manito: decisión del dueño, y el vectorial se retira

El dueño prefirió el SF Symbol de siempre (`hand.point.up.left.fill`, la
manito apretando el botón) sobre el guante vectorial de la casa que esta
sesión había puesto a la mañana. Se restauró el bloque original en
`TutorialHand` —con la decisión citada en el comentario— y
`VectorTutorialHandIcon` se **retiró** de `GameIcons.swift` (46 líneas, cero
llamadores): mismo criterio que `GamePanel`/`PanelBackground`, lo que queda
sin llamadores no se queda de recuerdo. La entrada del general que decía
«la mano es vectorial de la casa» quedó corregida — el general describe el
presente.

## Verificación del árbol final (main `9efc8f7` + manito)

| qué | resultado |
|---|---|
| `pacing-sim` (el criterio del dueño) | **24,00 h activas para maxear · 8 reencarnaciones** ✅ (los ❌ del bloque «Targets» son los objetivos de DISEÑO del plan F7.1c — brecha declarada por la rama, no regresión) |
| EconomyKit (`swift test`) | **234/234** ✅ |
| `FisuEvolutionTests` | **411/411** ✅ — incluye `PacingTests.theOwnersTargetsAreMet` (el contrato: 20-30 h, ≤8 reencarnaciones, Dios después de maxear) y los 3 que la sesión del tutorial veía en rojo, ahora re-pineados por el rebalance |
| `FisuEvolutionUITests` completa, sin skips | **48/48** ✅ (la rama había reportado 46 en su worktree; el 48 de acá coincide con el conteo de main — 46 de ella + los 2 del tutorial que su corrida no listaba por nombre; el número que vale es el de esta corrida final) |
| Warnings | 0 |

## Decisiones de esta tanda

| Decisión | Por qué |
|---|---|
| Merge `--no-ff` con mensaje propio, no fast-forward | el historial de la casa marca los merges de rama (`e4d4ce6`, `9ac8e0d`); un ff habría escondido el evento |
| La manito del sistema vuelve y el vectorial se borra (no queda «de reserva») | pedido textual del dueño + regla de prolijidad: código sin llamadores se retira; si alguna vez se quiere de vuelta, está en git (`39dd336`) |
| Los 3 rojos «preexistentes» de PacingTests ya no existen como categoría | el rebalance re-pineó la suite entera; la memoria del proyecto y el §6 del general quedaron sin la nota de «3 rojos conocidos» |
