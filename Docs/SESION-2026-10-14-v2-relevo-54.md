# Sesión 2026-10-14 — relevo 54: el `completo` de integ-r53, la ola 5–6 de E14 y las decisiones del dueño

Relevo automático (rutina `fisu-v2-relevo-a`). El disparo de las 00:03 cortó en la puerta (el 53 tenía el candado
con latido vivo); el dueño pidió «continúa» en el chat y, cuando el 53 liberó a las 00:18 con la Mac recién
reiniciada, el 54 tomó el candado normal. El dueño estuvo en vivo: pidió la 2.0 al 100 % «para mañana», la versión
en su iPhone y ayuda con Meta.

## Qué entró (en `v2i/integ-r54`, pusheada)

| Tarea | Commit / merge | Qué |
|---|---|---|
| Textos al catálogo (pedido del dueño) | `291ce357`, `20de90b6` | El dueño vio claves crudas en el iPhone: las 21 claves de E14 T6/T9/T10/T11/T13/T17 y del ranking, y las 46 de «dólar blue» (T7, `quitar` + `aplicar`), entran al catálogo. Regla nueva en `comun.md`: cada tarea aplica sus claves, no se espera a T26. |
| Rojos de UI del `completo` de integ-r53 | `2e29a8c4` → `948abacf` | 3 tests viejos (la barra con Ranking/C12/C18; D8 en Prizes) y un bug real: la ficha abierta desde Mejoras salía sin marco ni X porque `menuPager` se heredaba a las hojas; `fisuSheet` lo resetea. |
| Decisiones del dueño | `2e412124` → `8035f336` | Sólo el vendedor no repite; `package_rain` topa en ×10 (`packageRateStackCap`); saltear cooldowns 3/día; `VideoPlayerPool.maxLive = 2` en el SE (iPhone12,8 / 14,6). Pacing sin cambio (45,40 h). |
| E14 T19 (C11, C29) | `2bb994f3` → `5a4bc02b` | Mejoras con Personajes · Permanentes · Boosts y «Tu meta»; la Tienda sólo plata real; los cosméticos con blue a Pintas; lecciones re-apuntadas. |
| E14 T14 (C20, C30) | `33190760` → `6955033a` | `NoticesLayer`: los avisos bajo el HUD, sin comer toques, en una placa de la casa. La botonera del ascensor ya iba encima (test nuevo). |
| E14 T15 (C2, C6, C15, C16) | `d9a3a364` → `94cb7aba` | El visitante camina al horizonte (`StageLayout.standY`, 10 fondos calibrados), abre su popup solo, queda anclado a su piso y pide con la cara (`RequestBubbleNode`, arrastrar para entregar). |
| Ruleta y llave del debug | `f6d18f78` → `864e7fb2` | `WheelSpinGate` con unitario y RED por mutación (el UI corría contra el reloj del stub de 2 s); la llave del debug espera a ser tocable. No había regresión del debug: flake del 51. |
| E14 T18 (C28) | `893a422a` → `c33479d2` | El Paquete de la Aduana: pantalla con caras y chances (`PackageRoller.typeOdds`), tres toques, vuelo al sello, aviso; fuera `PackageOpeningPlayer`. |
| E14 T23 (C23, C24) | `19f7d5f3` → `38e86376` | La card de personaje nuevo bloqueante (`CelebrationKind.newCharacter`) y la imagen compartida con el personaje real y su skin. |

## Verificación

- `completo` de `55999d5f` (integ-r53): EK 904 · unit 1851 · store-unit 18 · Release 0 · iPad 4 · pipeline 108 ·
  Dios 45,40 h (6 reenc.) VERDES; UI 157 + 6 rojos, store-ui 2, SE 1. Resolución: 4 tests viejos/bug (fix-ui), Wheel
  (reloj del test), y Store ×2 / Visitor / SE por carga (lanzamientos de 316 s con dos agentes compilando; el SE dio
  2/2 aislado).
- `completo` de `38e86376` (integ-r54): EK 912 · unit 1885 + **3 rojos** · store-unit 18 · **UI 169 · 0 rojos** · iPad 4 ·
  SE 2 · Release 0 · pipeline 108 · Dios 45,40 h (6 reenc.) VERDES; **store-ui 0 + 3 rojos**. Los 6 son reales (con la
  máquina sola): `StoreUITests` ×3 en iOS 18.6 (la app tarda 60 s en quedar quieta y el `+` de la moneda no aparece:
  algo de iOS 18 frena el arranque, **prioridad 1**); `IAPCopyTests.theOroDescriptionTakesTheAmountFromTheData`
  (espera «ORO», ahora «blue»: test viejo frente a T7); `RankingWiringTests` ×2 (`rankingCardDue` da false:
  probablemente la card de personaje nuevo de T23 le gana el turno). `version-2` NO se adelanta hasta que estén verdes.

## Fuera del código

- **Meta Audience Network:** `app-ads.txt` en vivo con la línea de Meta y las ubicaciones creadas. El dueño puso el 2FA
  del portfolio en «Todos» y Meta bloquea activar el 2FA de su cuenta de Facebook («dispositivo no habitual», en la Mac
  y en el celular; no usa Facebook). **Decisión del dueño: la 2.0 se lanza sin Meta**; el adaptador queda (no puja).
- La Release de integ-r53 se instaló en el iPhone 15 Pro del dueño por `devicectl`; la de los textos arreglados quedó
  compilada (`build/DD-device`) pero el iPhone se quedó sin batería.

## Decisiones y trampas

- **Las claves de una tarea se aplican al integrarla.** Esperar a T26 dejó al dueño jugando con claves crudas.
- **Un «aislado» con dos agentes compilando no es aislado:** la app tardó 316 s en lanzar y el test cayó por eso.
- **Un agente con un build de fondo devuelve el reporte antes de terminar** (fix-ui lo hizo dos veces): el brief dice
  «no devuelvas con builds de fondo corriendo» y se lo reanuda con `SendMessage`.
- **Meta exige 2FA desde un dispositivo «habitual»:** con el portfolio en «Todos», una cuenta de Facebook sin uso queda
  afuera hasta que Meta la reconozca.

## Carries

- T14: en el SE el aviso pisa un chip ancho de la columna derecha (D14; decidir bajarlo o acotar los chips).
- T15: el globo de pedido nunca se vio en pantalla (sólo unit); número de piso en la card (`StageChips`); `SideRail` /
  `AppStoreScreenshotTests` usan el chip y la captura 04 mostrará el popup.
- T16 debe pasar `PickupLayout` de `baselineY` a `standY` (brief al día).
- T18: el rebote del sello es un aro (`RailSeal`); la fila del Paquete en Regalos va con T20; «¡Llega a tu piso Callejón!».
- T19: «!» de blue en el ícono de Mejoras; pista de lugares extra; la meta repite la 1.ª fila; pintas con blue dos veces
  en Pintas; los snapshots viejos `e6a-t8`, `e6a-t13`, `e9b-t2` tienen textos viejos (no re-aplicarlos a ciegas).
- T23: D5 (tutorial con «¡Compartir!»: hoy tiers 1–3 con «¡Genial!»; `tutorialTierCeiling = 0`); la imagen no lleva
  link de App Store (el id es `6814521946`); clave huérfana `share.offer %@`.
- `SideRailUITests.testFusionarTodoPorVideo` rojo visto por T18: lo dirime el `completo` de integ-r54.
