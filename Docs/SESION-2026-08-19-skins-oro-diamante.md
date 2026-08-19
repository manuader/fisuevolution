# Sesión 2026-08-19 — Oro y diamante para los 43, y el recorte elegido a mano

Continuación de `Docs/SESION-2026-08-18-recorte-de-fondo.md`, que es donde el
recorte por conectividad reemplazó a `rembg`. Acá esa herramienta se pone a
prueba contra el material más hostil que tiene el juego, y pierde en parte.

## Qué se pidió

Una skin de oro y una de diamante para cada personaje. Desbloqueo: el oro **no
se vende** —sólo maxeando las siete mejoras permanentes— y el diamante sólo por
un **bundle de USD 20** que las entrega todas juntas.

## Lo que se generó

**86 skins** (43 + 43), una por cada personaje con arte: los 44 tipos de
`tiers.json` menos `junior`, que es el nodo de elección de carrera y no tiene
sprite. Los prompts van en ASCII puro porque el keystroke de macOS pierde las
vocales con tilde SIEMPRE en el mismo punto (lección 1 del batch v3), y cada
skin adjunta como referencia el original de SU personaje.

## Tres bugs del pipeline, medidos

### 1. El umbral que descartaba lo bueno (`--ref-threshold`)

El runner descarta la imagen extraída si su huella queda a menos de MAE 12 de la
referencia — es el guard contra el bug #1 ("capturaba la referencia"). Pero la
huella es un thumbnail de **32×32** y el fondo blanco ocupa el **74%** del
cuadro, así que una variante que conserva la pose queda pegadísima al original:

| | MAE contra la referencia |
|---|---:|
| la misma imagen re-codificada o reescalada | ≤ 0,37 |
| el oro de `magnate_solar` (que ya vestía de amarillo) | 3,84 |
| un dorado típico | 9,51 |
| un personaje **enteramente negro** | 25,80 |

Con 12 no pasaba ninguno; con 4 seguía cayendo `magnate_solar`. Quedó en **1,5**,
que separa las dos poblaciones con margen. El default del runner ya lo trae.

### 2. La cola compartida regeneraba desde el principio

En modo cola los 86 comparten un proceso: si uno se cuelga hay que matar la
corrida entera, y al relanzar vuelve a empezar por el primero. Eso regeneró al
Fisura diez veces sin guardar nada. `scripts/batch_uno_por_uno.py` corre **un
asset por proceso** con `--only`, así un colgado muere solo.

### 3. Los reintentos se multiplicaban

El bucle del runner es `range(retries + 1)`, o sea que `--retries 1` son **dos**
generaciones por invocación. Multiplicado por los reintentos del driver daban
hasta cuatro por asset: 344 en vez de 86. El driver fija `--retries 0` y la
política de reintento vive en un solo lugar.

> El timeout NO puede bajar de ~250 s: es el piso real de generación medido. Un
> cap de 200 s mata la imagen unos segundos antes de que Gemini la renderice.

## El recorte: ninguna herramienta gana siempre

Se procesaron las 86 con las dos y se eligió a ojo, asset por asset.

- **Las 43 de oro → saliencia (`rembg`)**. El amarillo saturado no se confunde
  con blanco, así que el recorte sale limpio y además se lleva la sombra del
  piso, que el criterio topológico conserva por estar encerrada en el dibujo.
- **33 de diamante → conectividad**. El cristal es azul-blanco pálido, justo lo
  que la saliencia lee como fondo: se comía cuerpo y ropa (hasta **18%** de la
  silueta en `rey_asteroides__diamante`).
- **10 de diamante → saliencia**, las que traían sombra o telón blanco, donde
  perder algo de cuerpo cuesta menos que arrastrar una loza a los pies.

`scripts/elegir_recorte.py` deja las dos versiones conviviendo (el atlas y
`state/rembg/`, mismos nombres y tamaños), así que cambiar de opinión por asset
es una corrida. `recut_assets.py` y el barrido del atlas **saltean lo elegido a
mano** para que volver a correr el pipeline no pise la decisión.

## El catálogo: un id por material, no por personaje

Las 43 de oro comparten `id: "oro"` y las 43 de diamante `id: "diamante"`. Eso
obligó a mover la unicidad de `SkinsConfig.validate` de global a **(personaje,
id)**, porque la convención `<baseKey>__<skinId>` exige que el id sea el sufijo
y con unicidad global habría que inventar ids por personaje y romperla.

A cambio sale gratis lo que se quería: la propiedad se guarda **por id**
(`allOwnedSkins` es un `Set<String>`), así que tener `"diamante"` es tenerlo en
los 43 y **un único producto desbloquea el bundle entero** — sin inventar un
campo de paquete en la tienda.

Desbloqueo:
- **Oro**: `upgradesMaxed`. El flag lo calcula `GameState`, que es donde vive
  `upgradesConfig`; EconomyKit no conoce `upgrades.json` y recibirlo resuelto lo
  deja puro. No tiene producto, a propósito.
- **Diamante**: sólo `com.fisuevolution.iap.skins_diamante` (19,99).

## La silueta es el argumento de venta

`isSilhouette` tapaba sólo las de milestone y mostraba a color las pagas, que es
regalar justo lo que se vende: al comprarse **por bundle**, ver una sola saca las
ganas de pagar por las 43. Ahora la ficha esconde todo lo no adquirido y deja el
precio como única pista. **La tienda las sigue mostrando a color a propósito**:
ahí el arte ES el argumento; en la ficha el argumento es la expectativa.

## El merge con el rediseño v3

Sobre `origin/main` = `f5bd7b7`. Un solo archivo en común (`GameState.swift`),
resuelto solo. Verificado que sobrevivieran `maxLevel: 20`, el
`-weak_framework StoreKitTest`, las barras al 80% y los tres PNG recortados a
mano (`ui_elevator`, `ui_coin_plus`, `ui_gift_bow`), byte a byte los de la otra
rama.

**EconomyKit 209 · unit 380 (3 rojos) · UI 46/46.**

Los tres rojos son `PacingTests.strugglingPhaseLength`, `floorGradient` y
`godTiming`, y están **probados preexistentes**: fallan idénticos en
`origin/main` limpio, en worktree aparte con su propio simulador y sin una línea
de esta rama. No se tocaron — el tope de mejoras es decisión de balance del §5.
El diagnóstico, para quien los recalibre: el reporte da `godWall: nil` y
`finalMaxTier: 12`, o sea que la simulación se estanca antes de Dios. El tope
hizo su trabajo contra el overflow pero movió la curva y los rangos quedaron
viejos.

## Trampa nueva para el HANDOFF

**Commitear arte es dos lugares, no uno.** El commit que marcó las dos últimas
skins como `hecho` staged sólo los `.md` y dejó los PNG sin versionar:
`origin/main` quedó con 84 de 86 y se detectó recién verificando el push. Al
integrar arte hay que stagear el atlas Y `dropbox/procesadas/`, no sólo el
estado de la cola.
