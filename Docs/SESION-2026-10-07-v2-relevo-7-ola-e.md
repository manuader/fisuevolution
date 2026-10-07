# Sesión 2026-10-07 (relevo 7) — La ola E: el turno de los cambios, `GameState` partido, el ORO exacto y el ciclo más barato

Continúa `Docs/SESION-2026-10-07-v2-relevo-6-ola-d.md`.

Lo que un agente necesita saber sin leer el resto:

- **`version-2` en `60af174` tiene la ola E entera** (E1 T9, T9b, T10, T11 y T6c; E3a T6; E5a T1–T3;
  E4a T1; E11 T3 con sus arreglos). `rapido` sobre `60af174`: **VERDE (EK 447 · unit 683 + 1
  declarado · release 0 warnings)**, pusheado. `2a83e26` es la punta con `tasks.md` al cierre.
- **`GameState.swift` se partió**: 1.174 → 334 líneas, en siete extensiones nuevas
  (`+Types`, `+Bootstrap`, `+TowerSync`, `+FrameLoop`, `+Services`, `+Persistence`,
  `+Projections`). El costo, que Swift no deja evitar: **todos los `private(set)` pasaron a `var`**.
- **El ciclo de una tarea se abarató**: el agente corre `Tools/v2/oraculo.sh tarea <Clases>` en
  vez del `rapido`, el brief sale recortado con `Tools/v2/brief.py`, la revisión depende del riesgo
  y el `rapido` entero lo corre el controlador **una vez por ola** (§2).
- **El dueño pidió dos cosas** (§1): unos guiños escondidos en el contenido (Six Seven en tres
  lugares, "andá pa' allá, bobo" una vez) y un desarrollo más expeditivo y con menos tokens.
- **E1 T10 entró sin sus arreglos de revisión** (2 Important, §3). **El `completo` sobre la punta
  todavía no se corrió**: nada de la ola E pasó por UI, Store ni `pacing-sim`.
- Fuera de `version-2`: E11 T4 (`02cc5fb`, con un UI test rojo sin medir en la base), E2a T1
  (`434b0ee`), E6b T1 (`f9cd4b9`) y los mutantes de E5a T2+T3 (`f6f8e2f`). La cola del relevo 8 está
  en `tasks.md` §4.

## Cómo arrancó

- Relevo 7 del run AVO, desde las 15:46 (-0300), hasta ~19:00. Lo despertó el dueño escribiendo en
  la sesión, no la rutina `fisu-v2-relevo-a`: **sexto relevo seguido sin un despertar por cron ni por
  rutina** (relevos 2 a 7). El LOCK del relevo 6 tenía latido 14:43 y se tomó.
- Lo que pedía el handoff del relevo 6: los arreglos de E11 T3, mergear `v2/e5-premios`, la ola E
  (E1 T9 ∥ E1 T6c) y la decisión de partir `GameState.swift`.

## 1. Pedidos del dueño (no se vuelven a preguntar)

### Los guiños escondidos

El dueño pidió meter dos chistes sin anunciarlos. **Tope: no se suman más.**

| Guiño | Dónde | Cómo |
|---|---|---|
| **Six Seven** (×3) | El Turista Gringo | camiseta con el 67; prompts de arte 016 a 019 |
| | El Crypto Bro | "el gráfico hizo six seven" |
| | El Coach Ontológico | pide 67 toques (eran 60) |
| **"andá pa' allá, bobo"** (×1, sin nombrar a Messi) | La Vecina Chusma | "¿Qué mirás, bobo? Andá pa' allá… ¡ah, sos vos!" |

- Quedaron en `PLAN-v2.md` §2 y en los anexos A y B, en los planes de E4a y E4b y en la biblia de
  visitantes (`50b99ae`).
- **Los prompts 016–019 se editaron en `automatic-image-generation/projects/fisu-evolution-v2` y
  NO están commiteados**: ese proyecto nunca estuvo versionado. Si alguien regenera el proyecto
  desde otra copia, el 67 de la camiseta se pierde.
- El texto de los guiños vive en el plan y en los anexos, que son de donde E4a y E4b
  implementan a los visitantes; el 67 de la camiseta vive sólo en el prompt de imagen.

### Más expeditivo y con menos tokens

Se midió antes de tocar nada. **El `unit` tardó 1.244 s con tres agentes compilando, y 438 s con la
máquina libre**; como cada tarea corría un `rapido` completo, cada una pagaba ~30 min de verificación
que después se repetía al integrar. Los cambios, todos ya en `version-2`:

| Cambio | Qué hace | Commit |
|---|---|---|
| `oraculo.sh tarea <Clases>` | EconomyKit + build + **sólo** las clases de test que el agente tocó. Sin Release y sin la suite entera | `5d934d6` |
| `Tools/v2/brief.py <plan> <N> <salida>` | Copia el encabezado del plan y la `### Task N:` completa. El agente lee eso, no el plan entero | `5d934d6` |
| Revisión por riesgo | **sonnet** por defecto; **opus** sólo si la tarea cambia lógica de save, del frame loop, del turno del tablero o de dinero; **ninguna** (la lee el controlador) si es mecánica, sólo tests o docs; **mutantes a mano** en EK | documentada en `tasks.md` §1 (`17f4af8`) |
| El `rapido` completo, una vez por ola | Lo corre el controlador al integrar | — |
| `build/DD-oraculo.noindex` | El DerivedData del oráculo en una carpeta que Spotlight no indexa | `84cd717` |

El último nació de un pico de carga: el load average de 15 min **llegó a 346** con
`diskimagesiod` al 140 %, `mds_stores` al 37 % y `bird` al 31 %. Los gigas de DerivedData de
decenas de worktrees estaban en el camino de Spotlight. **No hay una medida de carga posterior que
confirme la mejora**: la causa es la sospechada y el cambio es barato, pero no está probado.

## 2. Decisiones del controlador

| Tema | Decisión | Por qué / qué descarta | Consecuencia |
|---|---|---|---|
| Partir `GameState.swift` | **Sí, como E1 T9b, entre T9 y T10** | 20 tareas pendientes lo tocan y, con un dueño por ola, iban de a una. Partirlo antes de T9 la retrasaba; entre T9 y T10 sólo retrasa a T10 | 1.174 → 334 líneas. **Todo `private(set)` pasó a `var`**: Swift no deja escribir una propiedad `private(set)` desde otro archivo, y las extensiones están en otros archivos. Se pierde la protección del setter, no se gana nada que el compilador pueda recuperar |
| T6c: `Transaction.all` vence el plazo | **La reconstrucción del ORO NO se cierra en 0**: se reintenta en el próximo arranque | Cerrarla en 0 deja el save de un veterano sin su ORO comprado para siempre, sin reintento (era la trampa E del relevo 5) | Fix `ec5d296`. Queda sin test de camino real: M3, abajo |
| E3a T6 / `RootView` | La migración de los 9 `.sheet` la aplicó **el controlador al integrar** (`60af174`) | `RootView.swift` es caliente y nadie lo tenía en la ola | Quedan **2 `.sheet` a propósito**: el share del sistema y el debug |

## 3. La ola E, tarea por tarea

| Épica | Tarea | Commit (agente → integración) | Revisión | Números |
|---|---|---|---|---|
| E1 | T9: el turno de los cambios del tablero | `65881ce` + `4572e6a` (merge `b09b4c4`) | el controlador re-revisó | carries a T10, T12 y T14 en el ledger |
| E1 | T9b: partir `GameState.swift` | `3d4fb8d` (merge `b09b4c4`) | multiset de líneas | 1.174 → 334 líneas |
| E1 | T10: la escena reproduce y revela | `26bccdd` (el agente `4c11a0a`; merge `b09b4c4`) | opus: 2 Important, **sin arreglar al cierre** | — |
| E1 | T11: el sorteo de eventos | `70f216f` (merge `b09b4c4`) | — | — |
| E1 | T6c: el ORO comprado exacto | `40df25e` + `4252402` + `ec5d296` (merge `b09b4c4`) | I1/M1/M2 arreglados | M3 y M4 abiertos |
| E3a | T6: hojas y popups en iPad | `428f55f` (merge `2087d71`) + `60af174` | — | los 9 `.sheet` de `RootView` los migró el controlador |
| E4a | T1: `RewardSpec` | `8d0a311` (merge `bba9e39`) | — | EK, el cimiento de E5–E7 |
| E5a | T1–T3: paquete, colchón y ruleta, puros | `b4800c5`+`a4c156f`, `d6a1421`, `4d1d426` (merge `bba9e39`) | mutantes a mano | T2+T3: **61 de 93 → 92 de 93** muertos (`f6f8e2f`, en `v2/e5-premios`) |
| E11 | T3: el manager 2.0, con los arreglos de la revisión | `3430d72` + `f7dff48` (merge `b0f6f6c`) | I1/I2 con mutación | `rapido` VERDE 653 + 1 |
| E2b, E9 | planes por tarea | `5b15b82` (15 tareas), `df2d688` (E9a 10 + E9b 10) | — | — |

**Ningún commit del rango `3956fd3..2a83e26` lleva `Co-Authored-By`** (verificado con
`git log --format='%(trailers:key=Co-Authored-By)'`).

### E1 T9, el turno de los cambios

- Un cambio de tablero que no hizo el jugador se planea en el acto y se aplica en su turno
  (E1 T7); T9 le agrega el **turno del tablero: confirmar una sola vez** (`65881ce`). Crea
  `GameState+BoardChanges.swift`. El `init` público de `BoardChangeOutcome`, carry de T7, estaba en
  su brief.
- **Dos arreglos de la revisión** (`4572e6a`): confirmar **revalida** el cambio antes de aplicarlo,
  y reencarnar **asienta la cola** de cambios pendientes.

### E1 T9b, partir `GameState.swift`

- Mecánica y sin cambio de conducta. El cuerpo de la clase se quedó con el estado y el `init`
  (334 líneas); el resto se mudó por zona. **El mapa símbolo → archivo está en `task-9b-report.md`**
  (ledger de E1).
- **Cómo se verificó**: el multiset de líneas movidas contra el archivo original. El script del
  agente dio **"bad 56"** y no era un error: eran las propiedades almacenadas cuyo único cambio es
  `private(set)` → `var`. El multiset de líneas es el juez correcto, no el diff por posición (§5).
- Lo que ganó: sumar una propiedad o una proyección deja de ser "tomar el archivo". Los planes
  que citan `GameState.swift:NNN` quedan apuntando a otro archivo; cada brief nuevo nombra la
  extensión.

### E1 T10, la escena (🔧)

- `BoardScene` reproduce los cambios como merges y revela lo que faltó (`26bccdd`).
- **La revisión opus encontró 2 Important**: un aborto con la condición equivocada y un arranque
  con arrastre (más 3 menores, en el ledger de E1). T10 está en `version-2` **sin esos arreglos**.
  Se le pidieron al agente de T10 (un commit encima de `4c11a0a`, en
  `worktree-agent-a6243c7787c9be294`); **no consta que hayan llegado al cierre**. Si no llegan, el
  relevo 8 despacha un agente nuevo con BASE `4c11a0a` y la revisión del ledger.
- Duda menor para el dueño, que queda: **un skip durante el vuelo re-reproduce el reveal**.

### E1 T11, el sorteo

- `70f216f`: el sorteo salta lo inaplicable, y **un sorteo vacío no gasta el intervalo**. El plan
  la ponía ∥ T10; por archivos también iba ∥ T9, pero eso no acorta el camino crítico.

### E1 T6c, el ORO comprado exacto

- Implementa la decisión del dueño del relevo 6 (`SaveConflictResolver.swift:67/:68`): un mapa
  crece-sólo id de transacción → ORO más un conjunto de revocados, `oroPurchasedLifetime` calculado,
  unión de `creditedPurchases` y `&&` en `purchasedOroReconstructed` (`40df25e`). Absorbe T6b.
- `4252402`: la reconstrucción **arranca con la tienda local**, con plazo y sin reentrada.
- `ec5d296`: el plazo vencido deja abierta la reconstrucción (§2).
- **Abiertos a sabiendas**: **M3**, `startLocalStore` no tiene test (se prueba a mano con una
  migración v1 → v2); **M4**, el saldo `oro` es por dispositivo, no por cuenta. **E6a tiene que
  pasar por `recordOroPurchase`**, no por `oroPurchasedLifetime +=`.

### E3a T6, las hojas en iPad

- `428f55f`: toda hoja se presenta con `fisuSheet`: cover transparente en iPad y panel de 640 pt.
- `RootView` lo migró el controlador al integrar (`60af174`, los 9 `.sheet`). Quedan el share del
  sistema y el debug.
- E3b presenta con `fisuSheet(item:)`: queda para su plan.

### E5a T2 y T3, y los mutantes

- El Colchón (`d6a1421`) y la Ruleta (`4d1d426`), puros, en EK. Entraron a `version-2` sin sus
  mutantes.
- **Los tests del brief dejaban vivos 32 de 93 mutantes (61 muertos).** Con los refuerzos
  (`f6f8e2f`, en `v2/e5-premios`) quedan **92 de 93**. Es la segunda vez que pasa en EK (T1 había
  dado 7 de 8 vivos, relevo 6): ver §5, trampa 4.

### E11 T3, los arreglos

- `f7dff48` cubre los dos huecos de la revisión: el v1 `false` ahora llega de verdad al maestro
  apagado, y la rama `.denied` del refresco queda cubierta. **Los dos con mutación verificada**.
  `rapido` sobre `b0f6f6c`: **VERDE 653 + 1**.
- E11 T4 (`02cc5fb`) quedó en `v2/e11-notificaciones`, sin mergear: **`MenuUITests.
  testAjustesTraeSusControlesYApagaLasParticulas` está rojo en `openMenu` (:288) y no se midió en la
  base**. No se declara hasta que el `completo` diga si es de T4 o ya estaba.

### Los planes de E2b y E9

- **E2b** (`5b15b82`): 15 tareas. **E9** (`df2d688`): E9a el motor, 10; E9b el currículo y el
  reset, 10. Contradicciones: E9, 17 (en `.superpowers/sdd/2026-10-07-v2-e9/plan-report.md`).
- **Todas las épicas tienen plan por tareas salvo E8 (el resto) y la parte de agente de E10.**

## 4. Los números del oráculo

### `rapido`

| Árbol | EK | unit (26.5) | Release | Veredicto | De dónde sale |
|---|---:|---:|---|---|---|
| `3956fd3` (relevo 6) | 357 | 639 + 1 | 0 warnings | VERDE | — |
| `b0f6f6c` (+ E11 T3 con arreglos) | — | 653 + 1 | — | VERDE | cuadra con 639 + 21 − 9 + 2 de los arreglos |
| `60af174` (`version-2` al cierre de la ola) | **447** | **683 + 1** | **0 warnings** | **VERDE** | la ola E entera |

- El relevo 6 esperaba 651 con E11 T3 (639 + 21 − 9); los 2 que sobran serían los de los arreglos.
  **Los 30 de 653 a 683 no están desglosados por tarea**: no se verificó contra los ledgers.
- Un número distinto después de integrar es un test perdido o duplicado.

### Lo que el próximo `completo` tiene que dar

Sobre `60af174` o la punta que venga: EK 447 (≈ 480 con las ramas de §6) · unit 683 + 1 (≥ 690 + 1)
· Store unit 13 · UI 59 (más lo que sume la ola E) · `StoreUITests` 2 · pipeline 49/0 · `pacing-sim`
igual (Dios en 30,73 h, 13 reencarnaciones) · Release 0. **Nada de la ola E pasó por UI, Store ni
`pacing-sim`**, y el último `completo` es el de `8d17b8d`.

## 5. Trampas nuevas

1. **El script de verificación de T9b dijo "bad 56" y no era un error.** Eran propiedades
   almacenadas cuyo único cambio es el modificador (`private(set)` → `var`). Para una mudanza
   mecánica, el juez es el **multiset de líneas** movidas, no la posición.
2. **StoreKit Testing con la máquina a load 300–500 entrega un reembolso minutos tarde.**
   `refundingAnOroPackLowersThePurchasedTotal` espera 180 s. Mirá `uptime` antes que el código.
3. **Un `du -sh` sobre `.claude/worktrees` no termina en 2 min** (43 worktrees, cada uno con su
   DerivedData). No lo hagas.
4. **Los tests del brief de E5a dejan vivos muchos mutantes** (T1: 7 de 8; T2+T3: 32 de 93). En
   EK, la revisión es por mutantes a mano, no un revisor de prosa.

## 6. El mecanismo (mantener lo que funcionó)

- **El controlador integra de a una rama y corre el `rapido` una vez por ola**, no una por tarea.
  Es lo que pidió el dueño; apunta a evitar los ~30 min de `rapido` por tarea. **No hay todavía
  una medida del ahorro**: conviene tomarla con el primer `rapido` de la ola F.
- **Los arreglos de una revisión van al MISMO implementador con `SendMessage`** y **sólo dentro de
  la misma sesión**: lo confirmó E11 T3 (agente nuevo, BASE `f084ef5`, el paquete
  `review-8d17b8d..f084ef5.diff`).
- **El brief recortado** (`brief.py`) más los carries del ledger dan una tarea que se lee en un
  vistazo. El agente no recorre el repo "para entender".
- **Una tarea de seguimiento chica se integra encima de la que movió su línea** (T5c sobre T8 en el
  relevo 6; T9b entre T9 y T10 en éste).

## 7. Lo que quedó abierto (relevo 8)

1. **Los arreglos de E1 T10**: 2 Important + 3 menores. Si el commit del agente llegó (encima de
   `4c11a0a` en `worktree-agent-a6243c7787c9be294`), cherry-pick en `v2/e1-correcciones` y en la
   integración. Si no, agente nuevo con BASE `4c11a0a`. `tasks.md` §4.1 fila 0.
2. **La integración de las ramas de épica sueltas**: `v2/e5-premios` (`f6f8e2f`),
   `v2/e11-notificaciones` (`02cc5fb`), `v2/e2a-mecanicas` (`434b0ee`) y `v2/e6-tienda` (`f9cd4b9`) →
   `version-2`, un `rapido`, push. Esperado EK ≈ 480 · unit ≥ 690 + 1 · release 0.
3. **Un `completo` sobre esa punta**. Decide `MenuUITests…ApagaLasParticulas` y valida UI/Store de
   las olas D y E.
4. **Carries abiertos** (en los ledgers):
   - **E1 T12**: `seal` corre también en `.inactive` y asienta la cola sin animación.
   - **E1 T14**: el `catch` de `applyBoardChange` **pierde un premio ya pagado**.
   - **E1 T10**: skip durante el vuelo re-reproduce el reveal.
   - **Un tier subido por evolve no se reporta a Game Center.**
   - **E6a**: `recordOroPurchase` en vez de `oroPurchasedLifetime +=`. **E3b**: presentar con
     `fisuSheet(item:)`.
   - **T6c M3 y M4**: `startLocalStore` sin test (prueba manual v1 → v2) y el saldo `oro` por
     dispositivo.
5. **Del dueño**: la prueba manual v1 → v2 (ahora el ORO comprado ya no se cierra en 0 si el plazo
   vence, pero sigue sin test de camino real), el batch de imágenes (con los 67 de la camiseta ya en
   los prompts 016–019, **sin commitear**), el OK de Higgsfield, los anexos A y B, las cinco dudas de
   E7b-b, `rentista_soles` (no borrar `v2-e8-pipeline`) y limpiar los worktrees de agentes.
