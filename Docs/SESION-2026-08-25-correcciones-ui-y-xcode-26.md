# Sesión 2026-08-25 — Tres correcciones de UI, y el día que Xcode saltó a 26.6

> Pedido del dueño, textual: «1- el boton de 'lets go' no tiene ningun tipo de
> margen superior ni inferior y se ve mal. 2- muchas de las veces que hay que
> tocar un icono del menu inferior (ej: fisujobs) no se ve la animacion del
> icono de la manito dando click. agregalo en todas las instancias en donde el
> usuario tenga que hacer click en algun lugar (lo mismo para achievements,
> cambio de skin, etc.) 3- cuando aparece un personaje especial: la skin del
> personaje deberia verse en la card. la card debe ser mucho mas grande para
> que se pueda apreciar la skin. al mantener al personaje especial debe re
> aparecer la card para saber cual es el beneficio que te esta dando». En el
> medio: «el juego se ve espantoso» — que resultó ser Xcode 26.6 recién
> actualizado, no un recurso perdido (§abajo).

## 1. El botón del cierre respira

`TutorialCard`: el `ArtButton` del «¡Vamos!» ganó `padding(.top, s8)` +
`padding(.bottom, s4)` propios además del `spacing` del VStack — pegado a los
dots y al borde del pergamino se leía embutido (captura del dueño). Verificado
con la foto que ahora saca el UI test del recorrido (attachment «RF-01 último
paso» — y de paso el test aprendió a esperar el `spring` antes de fotografiar:
la primera foto salía del paso anterior a medio fundir).

## 2. Una sola manito para toda la app: `TapHereHand`

La manito del sistema con su latido se extrajo a `TapHereHand`
(TutorialOverlay.swift, con las dos reglas del `repeatForever` en su doc) y la
mano de la fase pasó a componerla. Dónde vive ahora, además del spotlight de
la fase:

- **El coach de lecciones** (`TutorialTipView`): anillo + manito sobre el
  control señalado — era el hueco más visible («tocá el tab» sin dedo que lo
  muestre). Foto en vivo con `--uitest-lessons`.
- **FisuJobs, paso contratar**: sobre la fila RECOMENDADA (la señal
  `recommended` ya existía), sólo con la fase viva y sin contratar.
- **La tarjeta de Logros del menú**: junto al badge, mientras el badge viva —
  el puntito avisa, la mano pide el toque. Mueren juntos.
- **Pintas**: sobre cada tarjeta `.owned` mientras el jugador no se haya
  puesto NUNCA una pinta (`anySkinEverEquipped`, computed sobre
  `meta.activeSkinByType` — en `meta`, así sobrevive al prestigio y la guía
  no vuelve a molestar a un veterano).

## 3. La carta del special: la skin en grande, y el «mantener» la reabre

- `SpecialDropView` rediseñada: el retrato REAL del personaje a **168 pt**
  (`manifest.characters[id]` → `UIArt.characterImage`, mismo camino que el
  tablero; la estrella queda de fallback), detent 0,55 → **0,66**.
- **La misma carta sirve el drop y el RECAP** (`isRecap`): cambian título
  («Tu personaje especial»), botón («¡De una!») y a quién avisa el cierre.
  Payload nuevo `specialInfo` — NO pasa por la cola: como la ficha, la pidió
  el jugador.
- **El «mantener»**: `BoardScene` ganó long-press sobre los nodos
  `special.*` (mismo reloj de 0,45 s que la ficha; `touchesMoved` >12 pt lo
  cancela — esa rama es también el swipe de pisos). Los personajes MANDAN
  por diseño: si uno deambula encima del special, el press abre su ficha.
- Fixture nuevo **`--uitest-special`**: ancla el primer special del catálogo
  al piso visible y deja la carta del drop abierta — sin él ni la carta ni el
  recap se pueden fotografiar ni testear (el drop real es RNG sobre merges).
  La lección del CareerChoice, aplicada antes de que la pantalla envejezca.

## El vendaval: Xcode 26.6 a mitad de sesión

El dueño actualizó Xcode entre corridas y el juego «se veía espantoso». No
era un recurso perdido: era la cadena post-update, y cada eslabón está en la
trampa 30 del general. Resumen: (1) un **`runtime match` override**
(`iphoneos26.5 → 22G86`) hacía compilar con SDK 26 y correr sobre 18.6 — los
colores y paneles del asset catalog no decodifican y la escena SpriteKit sí
se ve (por eso «espantoso» selectivo) — y además le mentía al descargador
(«iOS is already downloaded»); (2) limpiado el override, bajó el runtime
**26.5 (23F77)** y `actool` volvió a andar; (3) el module cache de `build/DD`
mezclado entre SDKs se borra entero; (4) `SWIFT_TREAT_WARNINGS_AS_ERRORS`
ahora alcanza al clang importer y un header DEPRECADO de StoreKitTest (SDK
26.5) mataba el build → `OTHER_SWIFT_FLAGS: -Xcc
-Wno-error=deprecated-declarations` (los warnings de NUESTRO Swift siguen
siendo errores); (5) el `StoreKitTest` del **runtime 26 aborta**
`SKTestSession` fuera de un runner (SIGABRT ×2, y `dlopen` de XCTest NO
alcanza) → `StoreManager` degrada con `#available(iOS 26.0, *)`: la tienda
local por `simctl` queda ausente en 26; (6) y **StoreKit Testing está roto
ENTERO en el runtime 26** — mapeado con sims vírgenes: la sesión de los unit
tests no publica el catálogo (y no es timing: 14 s de reintentos dieron
vacío), el nodo de StoreKit en el TestAction del scheme no hace nada, y los
UI tests de la tienda también fallan. Respuesta: **split de destino** — las 3
suites de Store corren en 18.6, el resto en 26, documentado en la trampa 30 y
en §6 del general, con la señal de re-unificación anotada.

## La verificación: la matriz del split (receta §6, sims propios)

| qué | dónde | resultado |
|---|---|---|
| EconomyKit | `swift test` | **234/234** ✅ |
| Unit sin Store | sim iOS **26.5** | **401/401** ✅ |
| `StoreManagerTests` + `StoreProductsTests` | sim iOS **18.6** | **12/12** ✅ |
| UI sin Store | sim iOS **26.5** | **47/47** ✅ (+1: el recap del special, determinístico por la puerta de debug tras el press-lotería que costó una corrida) |
| `StoreUITests` | sim iOS **18.6** | **2/2** ✅ |
| **Totales** | | **unit 413 · UI 49 · cero rojos** |
| Smokes visuales (capturas) | sim 26.5 | arranque sano · paso final con aire · coach con manito · card del special con skin · recap por mantener ✅ |

El `pacing-sim` no se re-corrió: esta tanda no tocó un solo knob de economía
(el contrato del dueño quedó pineado en la verificación del merge).

## Decisiones de esta tanda

| Decisión | Por qué |
|---|---|
| La manito de Pintas se apaga para siempre con la primera equipada | guía de primera vez, no chicle: el gesto ya está aprendido |
| La manito de Logros vive lo que viva el badge | el circuito del badge ES la lección; sin cobrable no hay nada que pedir |
| El recap del special no pasa por la CelebrationQueue | lo abre el jugador (como la ficha): no compite por atención |
| La tienda local muere en runtime 26 en vez de pelear el abort | el framework lo exige; el costo real es sólo el caso `simctl` manual |
