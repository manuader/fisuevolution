# E12 — Ranking global de la llegada a Dios (diseño)

> Pedido del dueño, 2026-10-08. Entra en la 2.0. Las decisiones de esta página las tomó el dueño en
> la sesión de diseño y no se re-litigan; lo que queda abierto está marcado 🔒.

## Para qué

Un ranking que todos los jugadores ven, con quiénes llegaron a Dios y cuánto tardaron. El que se
lo speedrunea aparece primero. La competencia es el gancho: querer entrar (o subir) empuja a ver
anuncios y comprar boosts en la tienda. Resetear desde la Zona de peligro (E9) arranca una partida
nueva y, con ella, un intento nuevo de entrar.

## Decisiones del dueño

| Tema | Decisión |
|---|---|
| Qué se mide | **Tiempo real** desde el inicio de la partida hasta Dios (incluye las horas con la app cerrada), medido por el **reloj del servidor**. Ordena el ranking. Al lado se muestra el **tiempo jugado** (app en pantalla), que mide el teléfono y sólo se muestra. |
| Backend | **Supabase**: Postgres + Edge Functions. |
| Filas por jugador | El ranking muestra **la mejor partida de cada jugador**. "Mis partidas" muestra todas las suyas. |
| Moderación | **Lista de palabras prohibidas + Claude Haiku**, en el servidor. |
| Versión | **Dentro de la 2.0**, como épica E12. |
| Partidas viejas | Las partidas empezadas antes de la actualización **no entran**: llevan ventaja y su inicio no lo registró el servidor. Para competir, se resetea. |

## Lo que vive el jugador

1. **El cronómetro arranca con cada partida nueva**: al terminar el núcleo del tutorial de un juego
   nuevo (`core.finish`) y al confirmar el reset de la Zona de peligro (E9b T8). La app registra la
   partida (`start-run`) y el servidor anota la hora de inicio. Sin red, la app reintenta en cada
   vuelta a `.active`; el reloj cuenta desde que el servidor la registra, así que un corte de red
   nunca juega a favor del jugador.
2. **Tiempo jugado**: la app suma los segundos en `.active` de la partida en curso. Viaja en el
   envío final y se muestra; no ordena nada.
3. **Llegada a Dios** (tier 37, primera vez en la partida), después de la cinemática: tarjeta en
   estilo FisuJobs "¡Llegaste a Dios en 32 h 14 min!" con:
   - campo de nombre, máximo 15 caracteres, con contador. Los caracteres fuera de la lista
     permitida no se pueden escribir. Viene precargado con el último nombre usado;
   - `ActionPill` "Entrar al ranking" y "Ahora no".
   - Rechazo de la moderación: "Ese nombre no va, probá con otro", y el campo queda abierto.
   - Sin red: el envío queda pendiente en el save y se reintenta solo. La pestaña lo muestra como
     "Pendiente de envío".
   - "Ahora no" deja el envío pendiente; se puede completar desde la pestaña Ranking.
4. **Pestaña "Ranking"** en el menú deslizable (E3):
   - top 100: puesto, nombre, tiempo real y tiempo jugado. La fila propia, resaltada; si estás
     fuera del top, una fila fija abajo con tu puesto;
   - arriba, mientras hay partida en curso: "Tu partida: 12 h — el #10 lo hizo en 28 h", con un
     acceso a la Tienda (el gancho de monetización);
   - "Mis partidas": todas tus llegadas a Dios, con fecha y los dos tiempos;
   - "Reportar" en cada fila ajena (menú contextual, con confirmación);
   - sin red: el último ranking descargado, con la hora, y un aviso de que no está al día.

## El nombre: reglas de entrada

- 1 a 15 caracteres después de recortar espacios en los bordes, contados como caracteres visibles
  (grafemas).
- Permitidos: letras Unicode de los alfabetos latinos (incluye acentos y ñ), dígitos, espacio,
  `.`, `-` y `_`. Nada más: ni emojis, ni `<`, `>`, `'`, `"`, `;`, `\`, `/`, ni caracteres de
  control o invisibles (ancho cero, bidi).
- Espacios internos colapsados a uno. Normalización NFC.
- La misma regla vive en dos lugares, con los mismos casos de prueba: `NameRules` en EconomyKit
  (para la UI) y la función del servidor. **Manda el servidor.**
- Contra inyecciones, además de la lista permitida: el servidor escribe sólo con consultas
  parametrizadas (nunca arma SQL con texto del jugador) y la app muestra el nombre siempre como
  `Text` plano (sin Markdown, sin `AttributedString` interpretado, sin web views).

## Backend (Supabase)

**Tablas** (esquema `public`, RLS prendido en todas):

| Tabla | Qué guarda |
|---|---|
| `players` | `id` (uuid), `install_id_hash` (único), `last_name`, `created_at` |
| `runs` | `id`, `player_id`, `started_at` (servidor), `finished_at` (servidor), `real_seconds`, `played_seconds`, `name`, `status` (`active` · `finished` · `review` · `hidden`), `name_status` (`ok` · `pending` · `rejected`), `app_version` |
| `reports` | `run_id`, `reporter_player_id`, `created_at` (único por par) |
| `blocklist` | `term`, `lang` |

- **Vista `leaderboard`**: la mejor partida `finished` con `name_status = ok` de cada jugador,
  ordenada por `real_seconds`. Una partida con nombre `pending` o con 3+ reportes se muestra como
  "Anónimo".
- **RLS**: el cliente (clave anónima) no escribe ninguna tabla y sólo lee la vista. Todo lo que
  escribe pasa por las funciones, con la `service_role` del lado del servidor.

**Identidad**: un `installId` (UUID) generado en el primer uso y guardado en el Keychain, así
sobrevive a una reinstalación. Viaja en cada llamada; el servidor guarda su hash. Sin login.

**Edge Functions**:

| Función | Hace |
|---|---|
| `start-run` | Crea el jugador si no existe; cierra como abandonada cualquier `active` previa del jugador; crea la partida con `started_at = now()`; devuelve `runId`. |
| `finish-run` | Recibe `runId`, `playedSeconds` y `name`. Verifica que la partida sea del jugador y esté `active`. `finished_at = now()`, `real_seconds` por diferencia del servidor. Valida el nombre (reglas → lista de palabras → Haiku). Aplica el piso anti-trampa. Devuelve puesto y estado. |
| `leaderboard` | El top 100 de la vista, la fila del jugador y su puesto; "Mis partidas" con `mine=true`. Respuesta cacheable 60 s. |
| `report` | Anota el reporte. Con 3 reportes distintos, el nombre pasa a mostrarse como "Anónimo" hasta que el dueño lo revise. |

**Moderación** (en `finish-run`, en este orden):

1. Reglas de entrada (rechazo inmediato).
2. Lista de palabras: comparación sobre el nombre normalizado (minúsculas, sin acentos, con
   sustituciones típicas: 0→o, 1→i/l, 3→e, 4→a, 5→s, 7→t, @→a, $→s), buscando subcadenas.
3. Claude Haiku (último modelo Haiku disponible al implementar) con un prompt fijo que pide sólo
   `{"ok": true|false}` sobre si el nombre es ofensivo, discriminatorio, sexual, violento o se hace
   pasar por la app o el equipo, en español rioplatense e inglés. Timeout de 5 s.
   - Haiku no responde: la partida se guarda igual con `name_status = pending` y se muestra como
     "Anónimo". Un cron de Supabase reintenta los `pending` cada 15 min.
   - Rechazo: `name_status = rejected`; la app pide otro nombre y lo manda con `finish-run` sobre
     la misma partida (que ya tiene sus tiempos fijos).
4. La clave de Anthropic vive como secreto de Supabase; nunca viaja a la app.

**Anti-trampa**:

- El tiempo real lo pone el servidor: adelantar el reloj del teléfono no sirve.
- **Piso de plausibilidad** `minRealSecondsToGod`, en la configuración remota: una partida más
  rápida queda en `review` y no se publica hasta que el dueño la apruebe. Valor inicial: la mitad
  del perfil más rápido del simulador de pacing de E2b con boosts al máximo. E2b lo fija al cerrar
  la calibración, con el contrato de pacing ya medido.
- Una sola partida `active` por jugador; `finish-run` sólo sobre la propia.
- Límite de llamadas por `installId` (por ejemplo, 30 por hora) en las funciones.

## En la app

| Pieza | Dónde | Hace |
|---|---|---|
| `NameRules` | EconomyKit (puro) | Validación y normalización del nombre. |
| `RankingClient` | `Managers/Ranking/` | `URLSession` + `Codable` contra las cuatro funciones. Protocolo, para mockearlo. |
| `RankingStore` | `Managers/Ranking/` | Estado observable: run en curso, envío pendiente, último ranking cacheado, reintentos al volver a `.active`. |
| `MetaState.ranking` | save v6 | `runId?`, `playedSeconds`, `pendingSubmission?`, `lastName`, `eligible` (falso para las partidas anteriores a la 2.0). Migración: las partidas existentes quedan `eligible = false`. |
| Tarjeta de Dios | `UI/Ranking/` | La tarjeta del nombre, colgada del cierre de la cinemática de Dios. |
| `RankingView` | `UI/Ranking/` | La pestaña, "Mis partidas" y "Reportar". |

- Configuración remota (como la de anuncios): `ranking.enabled` (interruptor de emergencia),
  `minRealSecondsToGod` y la URL base.
- Bajo `--uitest*` y XCTest: `RankingClient` simulado; nunca red real.
- Textos `ranking.*` en es + en.

## Fuera de alcance

- Login, cuentas, Game Center (sigue apagado por flag).
- Rankings por temporada, semanales o de amigos.
- Premios por puesto.
- App Attest / DeviceCheck: si aparecen trampas por llamadas falsificadas, se suman en una versión
  siguiente. El piso de plausibilidad y la revisión del dueño cubren la 2.0.

## Pruebas

- `NameRulesTests` y los tests de la función del servidor con **la misma tabla de casos**: vacío,
  16+ caracteres, emojis, `<script>`, `' OR 1=1 --`, `Robert'); DROP TABLE`, `<b>`, ancho cero,
  bidi, solo espacios, acentos y ñ válidos.
- Tests de las funciones (Deno): tiempo real por servidor, una `active` por jugador, piso →
  `review`, Haiku caído → `pending`, rechazo → reenvío sobre la misma partida, 3 reportes →
  "Anónimo".
- `RankingStoreTests`: registro con y sin red, reintento, envío pendiente, partida vieja no
  elegible, reset → `start-run` nuevo.
- UI tests con el cliente simulado: tarjeta de Dios (contador, caracteres bloqueados, rechazo,
  sin red), la pestaña con la fila propia fuera del top, "Reportar".
- `LocalizationCompletenessTests` suma la familia `ranking.*`.

## Dependencias

- **E9b T8** (el reset en la app) para el `start-run` del reset. **E9b T9** para la Zona de
  peligro visible.
- **E3** (menú deslizable) para la pestaña.
- **E1** (save v6) para `MetaState.ranking`.
- **E8**: la cinemática de Dios; si no está lista, la tarjeta cuelga del festejo de Dios actual.
- **E2b**: el valor calibrado de `minRealSecondsToGod`.
- **E10**: App Privacy declara un identificador del dispositivo y contenido de usuario (el nombre)
  sin vínculo a la identidad ni seguimiento. Los Términos suman la regla de nombres y el contacto
  para reportes. Las notas a App Review explican la moderación, el reporte y la ocultación (guía
  1.2 de contenido generado por usuarios).

## 🔒 Lo que le toca al dueño

1. Crear el proyecto de Supabase y pasar su URL y su clave anónima.
2. Una API key de Anthropic cargada como secreto de Supabase (`ANTHROPIC_API_KEY`).
3. Aprobar la lista de palabras prohibidas inicial (es + en).
4. Revisar las partidas en `review` y los nombres reportados desde el panel de Supabase.
