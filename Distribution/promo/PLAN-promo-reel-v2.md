# FisuEvolution — Reel v2: «¿Qué hay en el último piso?»

**Pieza:** motion graphics 2D + simulación de gameplay, vertical 9:16, **45 s**, 4K 60 fps + 1080.
**Diferencia con la v1:** la v1 era un viaje *de fisura a Dios* que mostraba toda la escalera. La v2 es un **misterio**: la torre existe, el último piso brilla y nadie sabe qué hay. Lo único que se ve de verdad es el principio. Todo lo demás son siluetas con "?". El juego es descubrirlos, y el anuncio también.

## 1. Storytelling

1. **La pregunta (hook).** Una torre de 10 pisos en la oscuridad; arriba de todo, una luz dorada y una silueta con "?". *"¿QUÉ HAY EN EL ÚLTIMO PISO?"* La cámara baja piso por piso, todos cerrados, hasta el callejón: *"VOS ARRANCÁS ACÁ."*
2. **El juego, en tus manos.** El callejón se vuelve la pantalla del teléfono con la UI real del juego (HUD, ascensor, barra inferior). Simulación de una partida, con el dedo:
   tocar → juntar plata → contratar → arrastrar y fusionar → **¡NUEVO!** → laburan solos → **¡PISO NUEVO!** → elegir carrera → bonus y cofres → eventos y especiales → mejoras → ganancia offline → **reencarnar**.
3. **La respuesta que no damos.** Salimos del teléfono a la torre: ya hay pisos prendidos, pero arriba sigue la luz. *"+30 PERSONAJES. DESCUBRILOS UNO POR UNO."* Vuelve la pregunta del principio y cierra con la descarga.

## 2. Qué se revela y qué no

| Se ve completo | Sólo silueta / "?" |
|---|---|
| El Fisura (y sus pintas: De Oro, Segunda Vida), El Trapito, Limpiavidrios, Cartonero, El Mantero | Todos los personajes de los pisos 2 a 10 |
| Crypto Bro (es el especial de las capturas públicas) | Dios: sólo una luz y una silueta arriba de todo |
| Las 4 carreras del popup de la UBA (así es la UI real) | Los demás especiales |

## 3. Todo el juego en 45 s (textos de la app, en español)

| s | Sistema | Qué pasa en pantalla | Texto |
|---|---|---|---|
| 0–5 | **Torre** | Bajada lenta por los 10 pisos cerrados (siluetas + candado) | ¿QUÉ HAY EN EL ÚLTIMO PISO? · VOS ARRANCÁS ACÁ. |
| 5–9 | **Tap** | Se arma la UI. Toques con monedas que vuelan al contador. Un toque crítico (mejora *Pegarla*) | TOCÁ. JUNTÁ PLATA. |
| 9–13 | **Contratar + fusionar** | Pill de contratación "El Fisura · 25" → cae un segundo Fisura → arrastre → fusión → **¡NUEVO!** El Trapito | CONTRATÁ. FUSIONÁ. |
| 13–16 | **Ingreso pasivo + piso nuevo** | El tablero se llena; monedas solas y /s subiendo. Dos Cartoneros → El Mantero **sube al piso de arriba**: ¡PISO NUEVO! Ciudad, ascensor | LABURAN SOLOS. · CADA PISO, ALGUIEN NUEVO. |
| 16–20 | **Carrera** | Popup real: "¡Te recibiste en la UBA! ¿Y ahora qué?" con las 4 carreras y su premio | ELEGÍ TU CARRERA. |
| 20–25 | **Regalos: bonus + cofres** | Panel Regalos: racha diaria, boosts (Unos Mates, Café Cargado, Asado del Domingo, Milanesa, Modo Enfocado). Se activa uno y el multiplicador sube. Cofre de pintas → ¡Pinta nueva! **De Oro** para El Fisura | BONUS, COFRES Y PINTAS. |
| 25–29 | **Eventos + especiales** | Banner "¡Cayó el Plan Platita! x3" → lluvia de monedas. Banner "Se cayó Mercado Pago". Popup "¡Apareció un personaje especial!" Crypto Bro | SOBREVIVÍ A LA ECONOMÍA. |
| 29–33 | **Mejoras + offline** | Panel Mejoras: Más Platita, Dedos Curtidos, Pegarla, Modo Siesta subiendo de nivel. "Mientras no estabas… Cobrar" | MEJORÁ TODO. GANÁ DURMIENDO. |
| 33–38 | **Reencarnar** | "¿Reencarnar?" +ORO, multiplicador ×1,0 → ×1,6 → espiral de luz → renace el Fisura con la pinta **Segunda Vida**, todo más rápido | REENCARNÁ. CADA VIDA, MÁS RÁPIDO. |
| 38–42 | **Misterio** | Zoom out a la torre: pisos prendidos abajo, siluetas arriba, la luz dorada del último piso | +30 PERSONAJES · DESCUBRILOS UNO POR UNO. |
| 42–45 | **CTA** | Ícono real de la app, "DESCARGALO GRATIS", badge App Store, **Ader Games** | ¿QUÉ HAY EN EL ÚLTIMO PISO? |

## 4. Ritmo: más lento y más fluido

- 100 BPM (en la v1 eran 120). Un plano cada 3–5 s en lugar de cortes cada ½ beat.
- Nada de cortes secos. La cámara nunca se detiene: travellings, zooms dentro del teléfono hacia cada panel y vuelta, y fundidos por movimiento.
- Easings largos (`cInOut`, `expoOut` de 0,6–1 s), textos que suben con fundido, sin los golpes de tinta de la v1. Temblor de cámara mínimo, sólo en fusiones y en la reencarnación.
- Motion blur sólo en los movimientos de cámara grandes.

## 5. Marca

- **Ader Games** (logo del sitio oficial, `public/brand/logo-mono.png`) como firma del estudio en el cierre. El emblema del Fisura con corona ya no se usa como logo de empresa.
- Ícono real de la app (`public/fisuevolution/icon.png` del sitio).
- UI reconstruida desde las capturas reales del juego y los assets de `ui.atlas`: HUD (moneda + /s, ascensor, multiplicador), barra inferior (Contratar · Mejoras · Vestimenta · Bonus · Tienda · Menú), paneles de pergamino y madera con moño, botones verdes. Textos tomados de `Localizable.xcstrings`.

## 6. Pauta

- v1 y v2 en A/B. La v2 debería retener mejor en el tramo medio (curiosidad sostenida) y convertir mejor a instalación, porque muestra la profundidad del juego.
- Copy sugerido: *"Nadie sabe qué hay en el último piso. Arrancás de fisura. 📱 Gratis en iPhone."*
