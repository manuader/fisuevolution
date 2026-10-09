# SESION 2026-10-08/09 — La sesión del dueño: relevos automáticos, E12, E13 y todos los videos

Sesión paralela a los relevos, con el dueño presente. No tocó código Swift: armó la maquinaria de
relevos, sumó épicas al plan y generó todo el arte animado. Lo que sigue es lo que un agente nuevo
necesita saber y no está en el plan ni en el tablero.

## Los relevos se encadenan solos

- La rutina `fisu-v2-relevo-a` corre **cada hora** (`0 * * * *`). Su prompt vive en
  `~/.claude/scheduled-tasks/fisu-v2-relevo-a/SKILL.md` y trae la puerta (candado con latido < 45
  min → sale; cuota 5 h ≥ 85 % o semanal ≥ 95 % → sale), la llegada (`DUENO.md`, `ESTADO.md`, plan al
  día) y el cierre.
- **Regla dura del dueño**: ninguna sesión se borra, limpia ni termina con subagentes en vuelo. No
  `clear_session`, no `TaskStop` a un subagente que trabaja. El latido del candado lo mantiene un bucle
  de fondo cada 10 min.
- Las sesiones arrancan en modo auto (`~/.claude/settings.json → permissions.defaultMode: "auto"`, lo
  puso el dueño con un comando propio): por eso una ejecución sin el dueño ya no se cuelga en un
  permiso.
- La rutina `-b` se borró.
- **Canal fijo con el dueño**: `.claude/avo/2026-10-06-fisu-v2/DUENO.md` (pedidos `[ ]` y reglas
  permanentes). **Tablero para el dueño**: `ESTADO.md`, reescrito en cada borde de tarea.

## Lo que el dueño sumó al plan

- **E12 — Ranking de la llegada a Dios** (Supabase, moderación con lista + Claude Haiku). Proyecto
  `oejmjpwfxpwzzakdjxwp` creado; `ANTHROPIC_API_KEY` cargada en Secrets; **lista de palabras
  aprobada el 2026-10-09** (`supabase/blocklist/propuesta.txt`, 137 términos).
- **E13 — Ajustes del feedback de la v1** (ítems 1–12) más:
  - ítem 13: la **botonera colgante del ascensor** (mantener apretado el ícono del HUD; una columna;
    sin nombres; sin oscurecer) y el **viaje en cabina** al elegir piso en la placa o en el mapa,
    nunca al scrollear;
  - ítem 14: la **barra de abajo simétrica** (sin la Tienda, que queda en el "+"; íconos más
    grandes, sin rótulos).
  - Referencia visual del dueño: `Docs/superpowers/specs/referencias/2026-10-08-ascensor-y-barra.png`.

## Los videos (Higgsfield)

- **Aprobados por el dueño, todos** (2026-10-09). Fuente de verdad: `revision.json` en
  `automatic-image-generation/projects/fisu-evolution-v2/video/` (135 en `va`; los dos
  `sp_influencer` originales en `obviar`, los reemplazan las `_v2`).
- **Inventario**: 18 retratos, 53 personajes de cuerpo entero, 26 visitantes (acción y habla), 8
  eventos (ilustración nueva + loop), Paquete y Colchón (espera + apertura), 10 íconos de la tienda,
  10 fondos de piso, cabina del ascensor y 4 cinemáticas con sonido (intro, reencarnación, arresto,
  Dios).
- **Primera tanda integrada** (27 piezas, 9,5 MB). **La segunda tanda la procesa un agente en la rama
  `v2/e8-videos`**; avisa en `DUENO.md` cuando la pushea.
- Spec de integración: `Docs/superpowers/specs/2026-10-08-v2-e8-animaciones-design.md`; plan Swift:
  E8d (15 tareas).

### Trampas que costaron créditos

- **Fondo claro siempre** (regla del dueño): los recortados van sobre blanco y se recortan con
  `whitebg_cutout.py`. Se generó una tanda de 18 retratos sobre verde que no se usó (~135 créditos).
- **Pedir gestos rompe los cuerpos enteros**: "un gesto con las manos" produjo manos de más. El método
  que funciona: misma imagen como primer y último cuadro; el prompt dice qué cambia (respiración,
  parpadeo, pelo), qué queda **congelado** con nombre (brazos, manos, dedos, objetos) y "exactamente
  dos brazos y dos manos"; estilo 2D plano fijado; cámara quieta.
- **Control de calidad cuadro por cuadro** (hoja cada 15 cuadros), no un cuadro del medio: así se
  escapó la influencer.
- **Texto en los props**: Seedance escribió "POLICE" en la libreta del arresto; hay que pedir
  "completamente en blanco, sin letras".
- **Higgsfield**: el generador de efectos de sonido (`mirelo_text_to_audio`) es sólo para su propio
  pipeline de juegos; los efectos se sintetizan con `Tools/audio-synth/generate_audio.py`. El
  servicio a veces rechaza lotes con "sin créditos" cuando hay muchos trabajos en cola: se reintenta.
- Créditos: quedan ~300 de 1.863 (vencen a fin de octubre de 2026).

## Para el próximo agente

1. Leer `DUENO.md`: lo que esté en `[ ]` va primero.
2. Integrar la segunda tanda cuando el agente avise; seguir E8d.
3. Activar la lista de palabras de E12 y cerrar su gate.
