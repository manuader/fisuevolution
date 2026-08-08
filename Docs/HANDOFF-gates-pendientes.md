# Los dos gates que quedan — RF-14 (audio) y RF-02c (App Store Connect)

> Escrito el 2026-08-07, cuando el programa de las 16 correcciones se cerró.
> **Estos dos no esperan programación**: esperan que el dueño consiga algo. Este
> doc existe para que conseguirlo sea mecánico y no haya que reconstruir el
> contexto. Estado y arquitectura: `Docs/HANDOFF.md`.

---

## RF-14 · Música y efectos

### Por qué está bloqueado

No hay con qué generarlo. Re-verificado el 2026-08-07: **no queda ninguna
herramienta de generación de audio en la sesión.** El único servidor que había al
empezar se desconectó, y su contrato igual prohibía usar sus modelos de música y
efectos para audio suelto.

Se destraba con **una** de dos cosas:

1. Conectar un MCP con música y SFX standalone.
2. Conseguir audio **CC0 a mano** — que era el plan original del proyecto;
   `AudioManager.swift` todavía tiene el comentario del `[GATE HUMANO]` de F5.10.

### El criterio de aceptación es humano, y eso no se puede saltear

Se puede medir nivel, duración, costura del loop y que el archivo exista. **El
timbre y el "cansa en la décima vuelta" los juzga una persona escuchando.** La
aceptación de RF-14 es del dueño.

Y ojo con la conclusión fácil: **lo que hay hoy está técnicamente bien.** Medido
el 2026-08-06 — `music_cosmic_loop` loopea con un salto de muestra de −73 dBFS,
los diez SFX pican exactos a −3,0 dBFS sin clipping. **El problema es estético,
así que más síntesis por código no lo resuelve.**

### La lista de compras

El contrato es el **nombre de archivo**: `AudioManager.SFX` es un enum con
`rawValue` = nombre, y `url(forResource:)` lo busca en el bundle. Soltar un
`.caf` con el mismo nombre lo reemplaza.

**Música** — `Resources/Audio/`, loop sin costura:

| Archivo | Duración hoy | Cuándo suena |
|---|---|---|
| `music_earth_loop.caf` | 20,0 s | Zona terrenal (alley → island) |
| `music_cosmic_loop.caf` | 26,7 s | Zona cósmica (moon → god_realm) |

No se agregan zonas musicales: son dos temas y la lógica de cuál suena no cambia.

**Efectos** — los diez, todos ya cableados a su evento:

| Archivo | Dur. hoy | Lo dispara |
|---|---|---|
| `sfx_tap.caf` | 0,06 s | Tap normal en el tablero |
| `sfx_coin.caf` | 0,18 s | Tap crítico o dorado · cofres · daily |
| `sfx_merge.caf` | 0,15 s | Merge que **no** asciende |
| `sfx_evolution.caf` | 0,50 s | Merge que asciende de tier |
| `sfx_buy.caf` | 0,12 s | Contratar |
| `sfx_error.caf` | 0,20 s | Acción inválida (5 caminos distintos) |
| `sfx_rare.caf` | 0,40 s | Unidad rara |
| `sfx_prestige.caf` | 0,90 s | Reencarnar |
| `sfx_event.caf` | 0,25 s | Evento |
| `sfx_daily.caf` | 0,30 s | Recompensa diaria |

Las duraciones son las de hoy: sirven de referencia de rango, no son un
requisito. Lo que sí importa es que `merge` (0,15 s) y `evolution` (0,50 s)
**suenen distinguibles**, porque son el par que más se escucha.

### ⚠️ Una corrección al spec: "integrarlo es cero Swift" no es exacto

El spec dice que integrar el audio no toca una línea de Swift. Es cierto para los
doce archivos de arriba — **pero RF-14 pide también un efecto para "piso nuevo
desbloqueado", y ese evento no existe.**

Verificado el 2026-08-07 recorriendo todas las llamadas a `audio?.play`: hay diez
y ninguna es de desbloqueo de piso. Cuando un merge asciende y abre piso, lo que
suena es `.evolution`, compartido con cualquier ascenso.

Para cumplir RF-14 entero hacen falta, además del archivo:

- un caso nuevo en `AudioManager.SFX` (`case floorUnlocked = "sfx_floor"`), y
- dispararlo en `GameState+Actions.performMerge`, en la rama `case .promoted`,
  que ya calcula `newlyHireableFloors` y es exactamente donde se sabe que se
  abrió un piso.

Son unas tres líneas. **No se hicieron a propósito**: sin el archivo el efecto
sería silencioso, no se puede testear que suene, y quedaría código muerto
esperando un asset que puede no llegar nunca. Se hace junto con el audio.

---

## RF-02c · Alta de los productos en App Store Connect

### Por qué está bloqueado

Necesita la cuenta de Apple Developer (USD 99). **Es lo único que falta**: la
tienda está entera y verificada contra `StoreKitConfig/FisuEvolution.storekit`,
con test de `SKTestSession` por producto.

### Qué hay que dar de alta

Diez productos. Los ids y los tipos tienen que coincidir **exactamente** con
`FisuEvolution/Resources/Config/products.json`, porque `Product.products(for:)`
**omite en silencio** cualquier id que no resuelva — sin error y sin log. Un
tipeo acá se ve como una tienda a la que le falta una fila.

| Product ID (sufijo de `com.fisuevolution.iap.`) | Tipo | Precio | Nombre |
|---|---|---|---|
| `starter_pack` | No consumible | 4,99 | Pack de Arranque |
| `remove_ads` | No consumible | 2,99 | Sin anuncios |
| `coins_small` | **Consumible** | 0,99 | Puñado de Plata |
| `coins_medium` | **Consumible** | 4,99 | Fajo de Plata |
| `coins_large` | **Consumible** | 9,99 | Bolso de Plata |
| `oro_small` | **Consumible** | 1,99 | Puñado de ORO |
| `oro_medium` | **Consumible** | 4,99 | Cofre de ORO |
| `oro_large` | **Consumible** | 9,99 | Bóveda de ORO |
| `skin_mundialista` | No consumible | 2,99 | Skin Mundialista |
| `skin_parrillero` | No consumible | 2,99 | Skin Parrillero |

Las descripciones en español y en inglés están en el `.storekit`, listas para
copiar. **El tipo importa**: marcar un pack de plata como no consumible lo deja
comprable una sola vez.

### Dos cosas que conviene saber antes de cargarlo

1. **El combo entrega tres cosas por dos caminos distintos.** La plata la
   acredita el camino de consumible (una vez, con guarda por ID de transacción
   en el save); quitar los ads y la skin salen por `currentEntitlements`, que
   StoreKit reescribe en cada sync. Por eso el combo es **no consumible** aunque
   dé plata: dos de sus tres cosas son restaurables.
2. **Restaurar compras no devuelve la plata**, y está bien: es consumible, se
   gastó. Lo que vuelve es quitar los ads y las skins.

### Precios

Son `[TUNEABLE]` y viven en el `.storekit`. La razón de cada uno está en
`balance-log`, sección "Los packs de la tienda". El combo a 4,99 está por debajo
de la suma de sus partes (2,99 + 2,99) a propósito.
