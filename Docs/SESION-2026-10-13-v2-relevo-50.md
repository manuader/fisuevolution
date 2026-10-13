# Sesión 2026-10-13 — relevo 50: la segunda ola de E14 (T4, T6, T28)

Relevo automático (rutina `fisu-v2-relevo-a`, sesión `local_ed19fe77`). Llegó con el candado libre, la cuota
semanal en 89 % y la máquina cargada (~200, después ~470–550) por otra sesión del dueño (ffmpeg y un
simulador). Despachó tres tareas de E14 y no más: con esa carga cada `oraculo.sh tarea` tardó entre 30 y 90
minutos y cada agente, entre 5 y 7 horas.

## Qué entró (integración `v2i/integ-r50`, base `47950dd9`)

| Tarea | Commit / merge | Qué |
|---|---|---|
| E14 T4 (C1, C22) | `c5e8d479` / `736e0916` | Fuera los 10 videos de fondo de piso (6,7 MiB del bundle) y los 43 de personajes base (8,2 MiB de ODR, packs `anim-piso-*`). Los pisos muestran la foto de 2048; el reveal del tier, la foto. `video_assets.py` sin la clase `fondo`; `personaje` sólo acepta `sp_*`. |
| E14 T6 (C5) | `00bebb7f` / `b5d9b1aa` | Visitantes en un solo carril con bolsa barajada por visitante: cada uno sale una vez por vuelta, nadie dos seguidas (el vendedor tampoco; su tope diario baja de 20 a 2). `declineVisit` («No, gracias») para cualquiera, con un botón mínimo en el popup. Save v7 sin bump: tres campos opcionales. |
| E14 T28 (C31) | `5622e19e` / `75c3102a` | `ConsentGate`: la intro de una partida nueva espera a UMP → ATT; el tope de 10 s corre sólo sin diálogo en pantalla; si vence, el ATT espera un momento tranquilo (`isCalmMoment`). DEBUG: `--debug-consent-eea`, `--debug-consent-us`, `--debug-consent-reset`. |

Progreso: **278 de 306 (90,8 %)**. Destrabadas: T8, T10 y T22 (⏳).

## Verificación

- Cada tarea: `oraculo.sh tarea` VERDE (T4: 28 + EK 885; T6: 66 + EK 891; T28: 93 + EK 885), con RED por mutación en T6 y T28 (T4 no lo corrió: la carga lo hacía de una hora por corrida).
- Pacing tras T6: Dios **45,40 h · 6 reenc.** (sin cambio: el simulador no juega visitantes; E2b los mide por presupuesto). El regalo analítico por visita subió de 1,51 a 1,77 min al barajar por visitante, y se compensó con `coinsSecondsScale` 0,31 → 0,26 (1,48 min). `pacing-sim` suma la sección `VisitorRotation`: 544 visitas hasta Dios, los 18 visitantes, 33–34 cada uno de los que están desbloqueados toda la partida.
- `rapido` de la punta `75c3102a`: **VERDE** (EK 891 · unit 1812 · 0 rojos · Release 0 warnings), 14 min con la carga ya baja. El próximo `completo` toca al cerrar la ola 3 de E14.

## Decisiones del controlador

- T6 sin bump de save (opcionales tolerantes; un build viejo sigue leyendo). Se aceptó que borrara `antiRepeat` y `recentScripts` (muertos con la bolsa).
- T28 tocó `GameState.swift` y `GameState+Services.swift` fuera de su fila (aditivo: tres propiedades `@ObservationIgnored` y `attachConsentGate`). Aceptado.
- Con la carga sobre 200 y la semanal sobre 90 %, no se despachó la ola siguiente (T8 · T10 · T3).

## Para el dueño

1. **La bolsa y el tope diario:** si sólo un visitante tiene cupo y fue el último, la regla «nunca dos seguidas» deja el resto del día sin visitas (en el tier 1: el vendedor con su tope, el turista no tiene una tercera). El revisor propone permitir repetir salvo el vendedor. ¿Así o con la excepción?
2. Al actualizar, el vendedor puede repetir una vez (el save viejo no dice quién vino último).
3. Ver el ATT y el formulario de UMP de verdad en el iPhone (G4): en el simulador no se vio el cartel real.

## Carries

- T4: `VideoRole.background` sin usos; `CharacterSheetView` / `ArtClips.character` dan siempre `nil` para los base (limpieza); `Tools/asset-studio` (`video.py`, `catalogo.py`) todavía nombra `fondo` y personaje base: un master de esos tipos falla.
- T6: «No, gracias» puede no entrar bajo `VendorCardsView` en hojas chicas (lo rediseñan T11/T15). Claves en `Tools/v2/claves-pendientes/e14-t6.json` (las vuelca T26).
- T28: sin fila en el panel de debug para el consentimiento (sólo argumentos de lanzamiento).

## Trampas

- **Con la máquina sobre 400 de carga, una tarea chica de E14 tarda 5–7 horas** (el `build-for-testing` solo, 70 min). Con otra sesión pesada en la máquina, dos tareas a la vez es el techo práctico.
- **Un `Bash` de fondo con `cd X && a; b` puede correr `b` fuera de `X`:** el primer `rapido` del relevo murió con `no such file: Tools/v2/oraculo.sh`. En comandos de fondo, rutas absolutas siempre.
- **El `Package.resolved` de la integración se resuelve una vez** (`xcodebuild -resolvePackageDependencies`, 6 pines con la mediación) y se copia a cada worktree de tarea: el de `.claude/worktrees/version-2` no sirve (el 49 le sacó los pines de mediación).
