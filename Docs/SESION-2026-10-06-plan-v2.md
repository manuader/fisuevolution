# Sesión 2026-10-06 (noche) — El plan maestro de la 2.0

El plan aprobado vive en **`Docs/PLAN-v2.md`**: épicas E0–E10, decisiones, diseño por épica,
anexos de contenido y protocolo de relevo automático. Este documento guarda el **porqué**: lo que
se midió antes de decidir, lo que se descartó y las trampas de la planificación. No repite el plan.

## El pedido

- **19 pedidos** salidos del feedback de los primeros días de la v1.0.0 (~100 descargas y USD 20
  en una semana) y de capturas de Cow Evolution como referencia: bugs, pacing, precios, cajas,
  ruleta, visitantes que piden cosas, tienda de ORO, más anuncios, iPad, tutorial no salteable e
  IAP en inglés.
- Durante la sesión llegó la **crítica de un jugador avanzado** (Marco): ORO fácil, pisos
  chicos, no saber en qué piso estás, la barra de abajo confusa y los pisos bajos sin sentido.
- El dueño pidió **no decidir nada por él**. Todo se le preguntó: 15 rondas, ~55 decisiones.
- Al aprobar, sumó el **relevo automático de agentes** a los 300.000 tokens de contexto, con el
  harness AVO y las skills de documentación.

## Lo que se midió antes de decidir

Cada pedido se verificó contra el código de `version-2`. Cinco no eran lo que parecían:

| Pedido | Lo que el dueño veía | Lo que pasa en el código |
|---|---|---|
| Pasivo congelado en background | "recogió cero en una hora" | Al volver: `.background → .inactive → .active`. La rama `.inactive` re-sella `lastSeenTimestamp = ahora` y **lo guarda**, así que `.active` mide ~0 s, debajo del umbral de 30 s. Encima, el popup con el ×2 sólo sale si se acreditó algo: **un anuncio que nunca se ofreció**. |
| "El 50 % del Abogado no se aplica" | el timer corre y los precios no bajan | **Sí se aplica**, pero sólo a contratar. El mismo merge de la carrera sube la frontera, y los precios suben ×2,99: a la vista, **×1,49**. "Cayó Mercado Pago" (×2) lo anula del todo. |
| "Se fusionó solo mientras dormía" | un personaje nuevo sin verlo | El evento **"Startup comprada"** evoluciona la mejor unidad a un tier nunca visto, sin revelación. El reconciliador puede abrir pisos y auto-fusionar. Un evento vencido dispara apenas volvés. Y **elegir carrera nunca reveló el T11**. |
| Premios de carrera que no sirven | 3 M teniendo 70 M | Todos los premios valen `k × passiveUnlockCost(maxTier)` = 120·k s de **una** unidad sin mejoras. Ignoran el multiplicador de piso (hasta ×620), el ORO, las mejoras y la cantidad de unidades. |
| Precios que se disparan | "compré muchos y ahora no puedo comprar nada" | El contador es **por tipo**, de por vida en la run, y no baja al fusionar. Apoyarse en un tipo da una doble exponencial. El atajo viejo, que vendía sólo el tier base, empujaba a eso; `version-2` ya lo corrigió. |

**Números que ordenaron el diseño**:

- **ORO al llegar a Dios ≈ 12.380** (`L = 2,349e26` con `(L/1e10)^0,25`), contra **193** que
  cuestan las 7 líneas. Por eso la tienda de ORO necesita precios en escala (1 h de producción
  ≈ 90 ORO) y topes diarios: si no, tarde en la partida todo es gratis.
- **Las reencarnaciones las decide la política del bot, no el juego.** Con "reencarnar al
  multiplicar el ORO por (1+m)", `R ≈ ln(ORO_dios/ORO₁)/ln(1+m)`. El bot de hoy usa m = 1 y da
  13; con m = 4 (×5) da ≈ 6. "4–6 reencarnaciones" es un contrato sobre esa política, que el
  dueño eligió.
- **Los fondos originales son de 1024 px**: un iPhone Pro Max ya los estira ~3×, así que
  regenerarlos mejora iPhone e iPad. Los personajes no necesitan arte nuevo para iPad si la
  celda se topa en 112 pt (estirado ≤ 1,18×).
- **El tablero en un iPad 13" hoy**: personajes al 29 % del alto y estirados 2,1×, y la
  revelación estirada 3,7×.
- **Contratar gratis inflaría la curva**: `TowerActions.hire` suma los contadores aunque el costo
  sea 0. La carrera del Programador necesita `countsAsPurchase: false`.
- **`maxTierReached` tiene 6 escritores**: suavizar el salto de precios exige un único
  `raiseFrontier`.

## Lo que se descartó, y por qué

| Descartado | Motivo |
|---|---|
| Fisu Coin como cripto adentro del juego | Apple 3.1.1 prohíbe desbloquear contenido con cripto; 3.1.5 exige cuenta de Organización (la del dueño es Individual); la CNV (RG 1058/2025) exige registro PSAV. Queda como memecoin **fuera** de la app, sin links ni menciones. |
| Intersticial con timer duro cada 2 min | La política de AdMob prohíbe intersticiales "inesperados" durante la interacción (riesgo de suspensión). Va cada ≥ 2 min **en pausas naturales**, alternando con el intersticial bonificado (con opción de rechazarlo). |
| Hotfix 1.1 antes de la 2.0 | El dueño eligió una sola 2.0 definitiva. |
| "Sin anuncios VIP" y suscripción | No los quiso. Las IAP nuevas son los packs reescalados y 3 ofertas de 24 h. |
| Heredar unidades al reencarnar | El dueño eligió heredar **sólo los pasivos**. |
| Precios baratos en los pisos bajos | Reabre el atajo de "comprar hondo" que cerró §5.2. Los pisos bajos ganan sentido con "pisos en marcha" (+5 % por piso completo). |
| Reacciones de campo | Descartadas por el dueño en la sesión de preparación de esta misma tarde. El plan no las porta. |
| iPad en horizontal | Sólo vertical, con `UIRequiresFullScreen`. Se anota el riesgo: el SDK 27 la ignora. |

## Diagnósticos de la planificación que costaron tiempo

- **Los subagentes de diseño cortaron dos veces por el límite semanal de Opus** (HTTP 429), con la
  sesión principal andando. El tercer intento, con `model: sonnet`, terminó los tres diseños.
- **`gh` no está en el PATH del shell de los agentes.** Clonar con
  `git clone https://github.com/<repo>.git`.
- **Los dos agentes de diseño propusieron escalas de ORO incompatibles**: packs de 30/100/240
  contra 160/550/1.400. Ganó la segunda porque sale de la fórmula real del ORO (≈12k al llegar a
  Dios). La primera suponía montos de ORO chicos que el juego no tiene.

## Herramientas que quedaron instaladas (globales, para todos los proyectos)

- **Harness AVO** (repo `manuader/avo-harness`, clonado en `~/Desktop/projects/avo-harness`):
  skill `avo-harness`, subagente `avo-supervisor` y la regla al final de `~/.claude/CLAUDE.md`.
- **Skills de documentación** `handoff-system`, `writing-session-handoff` y
  `writing-general-handoff`: enlaces simbólicos desde `~/.claude/skills/` a
  `~/Desktop/skills/documentation/`, que es la fuente canónica.
- **Relevo**:
  - el journal del run en `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el
    checkout principal y excluido de git;
  - el candado `LOCK`;
  - el protocolo en `PLAN-v2.md` §0;
  - mecanismo primario: `CronCreate` de un disparo + `clear_session("self")`; secundario: rutinas
    de la app.
  - **Sin probar todavía**: el primer relevo es el de esta sesión, que cerró con ~770.000 tokens de
    contexto. El agente que despierte anota en el journal si lo despertó el cron o si el dueño tuvo
    que escribir "continúa".
