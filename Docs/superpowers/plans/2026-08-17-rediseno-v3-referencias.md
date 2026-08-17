# Rediseño v3 — materiales de referencia en todas las pantallas

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** que las 13 pantallas (UI general, principal, FisuJobs, Upgrades,
Pintas, Regalos, Tienda, Ascensor, Menú, Organigrama, Stats, Logros, Ajustes)
se vean como las 4 imágenes de referencia del dueño, con un solo lenguaje
visual.

**Architecture:** el rediseño v2 ya tiene la ESTRUCTURA de la referencia
(marcos de arte 9-slice, GameCard, PricePill, SectionHeader, cabecera crema).
Lo que falta es la CAPA DE MATERIALES: interior pergamino cálido (hoy crema
plano = tarjetas invisibles contra el fondo), bordes tono-sobre-tono (hoy todo
tinta #2C2C2C), cinta con pliegues y destellos, pills 3D, y sacar del lenguaje
los dos marcos que no son de la referencia (`panel_reward` verde navideño en
Regalos → madera+toldo+moño; `panel_config` blanco pelado en la familia del
menú → marco de madera vectorial hermano del arte). Se toca la capa de
componentes compartidos primero (fase A: 5 tareas → el 90% del cambio se
propaga solo) y después cada pantalla (fase B: retoques puntuales).

**Tech Stack:** SwiftUI puro. Cero lógica nueva, cero strings nuevos, cero
claves de manifest nuevas. 1 archivo Swift nuevo (`PanelFrames.swift` →
`xcodegen generate` obligatorio). 2 colorsets nuevos en Assets.xcassets (no
requieren xcodegen).

## Global Constraints

- **Identidad FisuJobs** (regla del dueño, SUMA IMPORTANCIA): toda pantalla se
  revisa contra `FisuEvolution/UI/Jobs/FisuJobsView.swift`.
- **No re-litigar** las decisiones de la pantalla principal (barras gemelas
  crema fundidas, iconos 48/54 en platos 56/62, SE al límite 374/375, status
  bar oculta) ni las 5 de balance del HANDOFF §5.
- **Identifiers de accesibilidad intactos** — los pinean los tests de UI
  (`sheet.close`, `hud.*`, `jobs.hire.*`, `upgrades.tab.*`, `bonus.*`,
  `skins.*`, `gifts.daily.day*`, etc.). Ningún contenedor lleva identifier
  (trampa 9a-bis).
- **Contratos pineados por `GameArtComponentsTests`**: orden de `GameScreen`,
  `PricePill.text/spokenAmount`, `ProgressBar.clampedProgress`,
  `CountBadge.text`, `StaggeredAppearance.delay`, escala `Tokens` 4/8/12/16/24.
  No cambian.
- **`UpgradesFaceUITests` pinea el ancho 104 del retrato** de la fila de
  mejoras. No cambia.
- **Cero warnings** (`SWIFT_TREAT_WARNINGS_AS_ERRORS`), Swift 6 strict
  concurrency, sin `Timer` nuevos, sin `repeatForever` incondicional.
- **Cero strings nuevos**: no se toca `Localizable.xcstrings` (ni con scripts —
  trampa del catálogo).
- **Los archivos de la sesión paralela del dueño no se tocan ni se stagean**:
  `FisuEvolution/Game/State/GameState+Upgrades.swift`,
  `FisuEvolutionTests/UpgradesMenuTests.swift`, `Tools/asset-pipeline/*`,
  `*.atlas` ajenos.
- Trabajo en **worktree aislado** desde `main` LOCAL (no `origin/main`, que
  está 6 commits atrás — trampa 7), commits atómicos en español, doc de sesión
  commiteado al cierre de cada tarea (regla del dueño).
- Los popups (`GamePanel`: ficha, premio de skin, daily, offline, carrera,
  prestigio) **no están en el pedido**: conservan su arte. Sólo heredan los
  materiales que les lleguen gratis por los componentes compartidos.

## Materiales v3 (medidos de las referencias y del arte)

| Token | Valor | Uso |
|---|---|---|
| `PaletteParchment` | #F1E5C9 | interior de todos los paneles (base bajo el arte) |
| `PaletteBrown` | #7A4E26 | contornos cálidos: borde de tarjeta (op. 0.55), línea interna del marco, pliegues |
| Madera (vector) | #C98F52→#A9713C, línea #2F1915, bisel #D3B788 | marco de la familia del menú — muestreado de `panel_store@3x` |
| Verde oscuro | `PaletteGreen` mezclado 35% con negro ≈ #468450 | borde de pill verde |
| Naranja oscuro | `PaletteOrange` mezclado 35% con negro ≈ #A64522 | borde de pill naranja y de la cinta |
| Gris bloqueado | #E7E1D4 relleno / #B8B0A0 borde | GameCard.locked y StateBadge muted |

---

### Task 1: Base pergamino — colorsets + `PanelBackground` v3

**Files:**
- Create: `FisuEvolution/Resources/Assets.xcassets/PaletteParchment.colorset/Contents.json`
- Create: `FisuEvolution/Resources/Assets.xcassets/PaletteBrown.colorset/Contents.json`
- Modify: `FisuEvolution/UI/Art/GameArt.swift` (struct `PanelBackground`, ~línea 195)

**Interfaces:**
- Produces: `Color("PaletteParchment")`, `Color("PaletteBrown")` para todas las
  tareas siguientes. `PanelBackground(art:)` conserva su firma.

- [ ] **Step 1: colorsets.** Copiar el formato de
  `PaletteCream.colorset/Contents.json` (universal, components en hex 0xNN):
  Parchment `0xF1/0xE5/0xC9`, Brown `0x7A/0x4E/0x26`.

- [ ] **Step 2: interior pergamino en `PanelBackground`.** Reemplazar el body:

```swift
var body: some View {
    ZStack {
        // La base cálida de la referencia: pergamino con luz arriba y un
        // oscurecido sutil hacia los bordes, para que las tarjetas crema
        // se despeguen del fondo (hoy crema-sobre-crema = pantalla chata).
        Color("PaletteParchment")
        LinearGradient(
            colors: [Color.white.opacity(0.35), .clear, Color("PaletteBrown").opacity(0.10)],
            startPoint: .top, endPoint: .bottom
        )
        if let frame = UIArt.nineSlice(art, cap: 0.33) {
            frame
        }
    }
    .ignoresSafeArea()
}
```

- [ ] **Step 3: build rápido** (`xcodebuild build` en el worktree) — los
  colorsets tipografiados a mano rompen en runtime, no en compile: verificar
  con `swift test` NO alcanza. El build + un arranque en el simulador de la
  fase C lo cubren; acá alcanza con que compile.

- [ ] **Step 4: commit** `feat(ui): interior pergamino bajo los marcos de panel`

### Task 2: `PanelFrames.swift` — marco de madera vectorial + moño

**Files:**
- Create: `FisuEvolution/UI/Art/PanelFrames.swift`
- Test: `FisuEvolutionTests/GameArtComponentsTests.swift` (suite existente)
- Correr `xcodegen generate` (archivo Swift nuevo).

**Interfaces:**
- Produces: `WoodPanelBackground` (drop-in del `PanelBackground` para las
  pantallas sin arte de marco propio), `GiftBowOrnament` (moño para Regalos),
  `WoodPanelBackground.contentInset: CGFloat` (el `panelInset` de sus
  pantallas).

- [ ] **Step 1: test del contrato** (en `GameArtComponentsTests`):

```swift
@Test("el marco de madera publica el inset que usan sus pantallas")
func woodFrameInset() {
    // 22 de poste + 6 de aire = el equivalente del 30 medido de panel_store.
    #expect(WoodPanelBackground.contentInset == 28)
    #expect(GiftBowOrnament.defaultWidth == 150)
}
```

- [ ] **Step 2: implementación.** Marco: pergamino (mismas dos capas que
  `PanelBackground`) + banda de madera perimetral:

```swift
/// Marco de madera VECTORIAL para las pantallas sin arte de panel propio
/// (familia del menú). Hermano del `panel_store` del atlas: mismos tonos
/// (muestreados del PNG: madera #C98F52→#A9713C, línea #2F1915, bisel
/// #D3B788), mismos tornillos en las esquinas, sin toldo.
struct WoodPanelBackground: View {
    static let contentInset: CGFloat = 28
    private static let band: CGFloat = 22
    private static let wood = LinearGradient(
        colors: [Color(red: 0.788, green: 0.561, blue: 0.322),
                 Color(red: 0.663, green: 0.443, blue: 0.235)],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        ZStack {
            Color("PaletteParchment")
            LinearGradient(
                colors: [Color.white.opacity(0.35), .clear, Color("PaletteBrown").opacity(0.10)],
                startPoint: .top, endPoint: .bottom)
            frame
        }
        .ignoresSafeArea()
    }

    private var frame: some View {
        GeometryReader { geo in
            let outer = RoundedRectangle(cornerRadius: 34, style: .continuous)
            let inner = RoundedRectangle(cornerRadius: 18, style: .continuous)
            let innerRect = CGRect(origin: .zero, size: geo.size)
                .insetBy(dx: Self.band, dy: Self.band)
            ZStack {
                outer.strokeBorder(Self.wood, lineWidth: Self.band)
                // La línea oscura donde la madera encuentra el pergamino.
                inner.strokeBorder(Color(red: 0.184, green: 0.098, blue: 0.082), lineWidth: 3)
                    .padding(Self.band - 3)
                // El bisel de luz por adentro de la línea.
                inner.strokeBorder(Color(red: 0.827, green: 0.718, blue: 0.533).opacity(0.9), lineWidth: 2)
                    .padding(Self.band)
                // El contorno ink de afuera de todo.
                outer.strokeBorder(Color("PaletteInk").opacity(0.9), lineWidth: 3)
                cornerScrews(in: innerRect)
            }
        }
        .ignoresSafeArea()
    }
    // cornerScrews: 4 círculos Ø11 de #8A5A30 con borde #2F1915 de 2 y una
    // ranura diagonal de 5×1.5, centrados a 11pt de cada esquina de la banda.
}
```

- [ ] **Step 3: `GiftBowOrnament`.** Moño rojo vectorial (dos lazadas
  `Ellipse` rotadas ±28°, nudo `RoundedRectangle`, dos colas `RibbonShape`
  apuntando abajo), relleno #D94F3D con sombras internas #A63428, contorno
  `PaletteInk` 3pt, `defaultWidth` 150. `accessibilityHidden(true)`.

- [ ] **Step 4:** `xcodegen generate` + `swift test` de EconomyKit NO (no lo
  toca) + tests unitarios de la suite `GameArtComponentsTests` cuando corra la
  fase C. Compilar ahora.

- [ ] **Step 5: commit** `feat(ui): marco de madera vectorial y moño de regalo`

### Task 3: `GameCard` v3 + `StateBadge` v3 (tarjetas y badges de la referencia)

**Files:**
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`GameCard` ~57-94, `StateBadge` ~497-532)

**Interfaces:**
- API sin cambios (`Style.normal/.highlighted(Color)/.locked`; `StateBadge(text:systemImage:textAlignment:muted:)`).

- [ ] **Step 1: `GameCard`.** Radio 14→18. Borde: `accent ?? PaletteBrown.opacity(0.55)`
  2pt (highlighted: 3pt del acento + halo como hoy). Relleno: normal crema;
  highlighted: crema TEÑIDO del acento (`accent.opacity(0.16)` encima del
  crema — la tarjeta "puesta" de la referencia es amarilla, no crema con
  bordecito); locked: `#E7E1D4` con borde `#B8B0A0` y **sin** el
  `saturation(0.2)` de hoy sobre el CONTENIDO de texto — el gris de la
  referencia lo pone la tarjeta; la silueta ya la pone cada pantalla. Mantener
  `opacity(0.9)` para el conjunto locked.

- [ ] **Step 2: `StateBadge`.** Forma rectángulo-10 → `Capsule` (los badges de
  la referencia son píldoras). muted: relleno `#E7E1D4`, borde `#B8B0A0`,
  texto ink 0.6. No-muted: relleno `PaletteOrange.opacity(0.22)`, borde
  naranja oscuro (mezcla 35% negro), texto ink. Glifo 10→11pt.

- [ ] **Step 3: compilar. Commit** `feat(ui): tarjetas y badges con los materiales de la referencia`

### Task 4: pills 3D (`PricePill`, `ActionPill`, `GameToggle`, `IconButton`, `CountBadge`)

**Files:**
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` + `GameArt.swift` (GameToggle)

**Interfaces:** API y contratos hablados sin cambios.

- [ ] **Step 1: helper de tono.** En `GameArtComponents.swift`:

```swift
extension Color {
    /// El borde tono-sobre-tono de la referencia: el mismo color, hundido.
    func deepened(_ amount: Double = 0.35) -> Color {
        Color(uiColor: UIColor(self).mixed(withBlack: amount))
    }
}
// UIColor.mixed(withBlack:) : multiplicar RGB por (1-amount), alpha intacta.
```

- [ ] **Step 2: `PricePill`/`ActionPill`.** Cápsula: relleno con gradiente
  vertical (`fill` aclarado 18% arriba → `fill` abajo), borde
  `fill.deepened()` 2.5pt (reemplaza al ink 3pt), y un **labio de luz**:
  `Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1.5)` inset 2.5 y
  recortado a la mitad superior con máscara `LinearGradient(white→clear)`.
  Estado no-affordable de `PricePill`: crema + borde `PaletteBrown.opacity(0.6)`
  (la píldora "47" crema de la referencia de FisuJobs). Sombra igual.

- [ ] **Step 3: `GameToggle`** borde ink→`PaletteGreen.deepened()` (ON) /
  `#B8B0A0` (OFF). **`IconButton`** borde ink 3→`PaletteBrown.opacity(0.7)` 2.5.
  **`CountBadge`** borde ink→`PaletteBrown.opacity(0.6)`.

- [ ] **Step 4: compilar. Commit** `feat(ui): pills con volumen y bordes tono-sobre-tono`

### Task 5: `SectionHeader` v3 (cinta con pliegues y destellos) + `PanelTitleBanner` v3

**Files:**
- Modify: `FisuEvolution/UI/Art/GameArtComponents.swift` (`SectionHeader` 110-165)
- Modify: `FisuEvolution/UI/Art/GameArt.swift` (`PanelTitleBanner` 273-289)
- Test: `GameArtComponentsTests.swift`

**Interfaces:**
- `SectionHeader` API igual. `PanelTitleBanner` gana `var icon: (() -> AnyView)? = nil`
  (default nil → cero call-sites rotos).

- [ ] **Step 1: test** del nuevo shape:

```swift
@Test("la cola de la cinta es un paralelogramo con muesca que cae hacia afuera")
func ribbonTailPath() {
    let path = RibbonTailShape(side: .leading).path(in: CGRect(x: 0, y: 0, width: 30, height: 40))
    #expect(!path.isEmpty)
    #expect(path.boundingRect.width <= 30.5)
}
```

- [ ] **Step 2: cinta.** Composición en 3 capas detrás del label:
  1. **Colas**: `RibbonTailShape` 30×alto+8, salen por detrás a izquierda y
     derecha, 4pt más abajo que la banda (la referencia las muestra caídas),
     relleno naranja oscuro (`PaletteOrange.deepened(0.18)`), muesca en V al
     extremo (la del `RibbonShape` actual).
  2. **Pliegues**: dos triángulos `Path` de 10×8 en `PaletteOrange.deepened(0.5)`
     donde la banda tapa la cola (la esquina doblada de la referencia).
  3. **Banda**: `Rectangle` radio 6 con gradiente vertical naranja
     (arriba +12% luz), borde naranja oscuro 2.5pt.
  El label suma los **destellos**: `SparkleShape` (rombo de 4 puntas cóncavas)
  de 10pt en crema a cada lado del texto, `HStack(spacing: 8)`. Texto y sombra
  como hoy. El `RibbonShape` viejo queda (lo usan las colas y el moño).

- [ ] **Step 3: `PanelTitleBanner`.** Doble borde de la referencia: cápsula
  crema + borde `PaletteBrown` 3pt + **pinstripe interior**
  `Capsule().strokeBorder(PaletteBrown.opacity(0.35), lineWidth: 1.5)` con
  padding 4. `icon` opcional dibujado a la izquierda del texto (26pt), para
  que Regalos y Pintas metan su glifo ADENTRO de la cápsula como la
  referencia.

- [ ] **Step 4: compilar + commit** `feat(ui): la cinta gana pliegues y destellos; el título, doble borde`

### Task 6: Regalos a madera + moño (la referencia de Gifts)

**Files:**
- Modify: `FisuEvolution/UI/Gifts/GiftsView.swift`

- [ ] **Step 1:** `PanelBackground(art: "panel_reward")` →
  `PanelBackground(art: "panel_store")`; `panelInset` 38→30 (el medido de
  `panel_store`; actualizar el docstring). El moño:
  `.overlay(alignment: .top) { GiftBowOrnament().allowsHitTesting(false) }`
  sobre el `ZStack` raíz del `NavigationStack`, offset y=-6 para solapar el
  toldo como la referencia.
- [ ] **Step 2:** cabecera: `GameIcon` del moño se muda ADENTRO de
  `PanelTitleBanner(titleKey:icon:)`.
- [ ] **Step 3:** compilar + commit `feat(regalos): marco de madera con toldo y moño, como la referencia`

### Task 7: familia del menú a madera vectorial

**Files:**
- Modify: `MenuView.swift`, `StatsView.swift`, `OrgChartView.swift`,
  `AchievementsView.swift`, `SettingsView.swift`, `LegalView.swift`

- [ ] **Step 1:** en las 6: `PanelBackground(art: "panel_config")` →
  `WoodPanelBackground()`. `MenuView.panelInset` 34→`WoodPanelBackground.contentInset + 6`
  (=34: el número no cambia, cambia su origen; dejar el docstring apuntando al
  componente en vez del PNG).
- [ ] **Step 2:** compilar + commit `feat(menu): la oficina central y sus cuatro gabinetes en marco de madera`

### Task 8: Ascensor a marco metálico

**Files:**
- Modify: `FisuEvolution/UI/Popups/FloorMapView.swift`

- [ ] **Step 1:** `PanelBackground(art: "panel_dialog")` →
  `PanelBackground(art: "panel_upgrades")` (la torre es maquinaria — el mismo
  idioma industrial que Upgrades en la referencia); `panelInset` 36→40 (el
  medido de `panel_upgrades` en `UpgradesView`).
- [ ] **Step 2:** compilar + commit `feat(ascensor): marco metálico de maquinaria`

### Task 9: Upgrades — pestañas naranjas con glifo

**Files:**
- Modify: `FisuEvolution/UI/Store/UpgradesView.swift` (`tabButton` 152-175)

- [ ] **Step 1:** cápsula seleccionada `PaletteBlue`→`PaletteOrange` con borde
  `PaletteOrange.deepened()` 2.5 (referencia: Characters naranja). Glifo por
  pestaña delante del texto: `person.fill` / `star.fill` a 13pt (blanco
  seleccionado, ink 0.55 no). Identifiers intactos.
- [ ] **Step 2:** el groove: `PaletteInk 0.09` → `PaletteBrown.opacity(0.12)`,
  borde ink→`PaletteBrown.opacity(0.55)` 2.
- [ ] **Step 3:** compilar + commit `feat(mejoras): pestañas naranjas con glifo, como la referencia`

### Task 10: pase fino shops (FisuJobs, Pintas, Tienda) + bordes menores

**Files:**
- Modify: `FisuJobsView.swift`, `CustomizationView.swift`, `StoreView.swift`

Los tres ya heredan todo de las primitivas. Queda el borde de los retratos
(`JobPortrait`, `faceTile`, `SkinCard.preview`, `upgradeIcon`, `BoostGlyph`,
plates de `MenuView`/`GiftsView`): ink 2 → `PaletteBrown.opacity(0.7)` 2, y el
plato amarillo 0.35 → 0.30 (la referencia tiene los platos apenas más tenues).
El tachado del aviso confidencial (`FisuJobsView` 400) sube a
`PaletteInk.opacity(0.3)` sobre la tarjeta gris nueva.

- [ ] **Step 1:** aplicar y compilar por archivo.
- [ ] **Step 2:** commit `feat(shops): retratos y platos en el tono cálido de la referencia`

### Task 11: armonía del HUD (sin re-litigar nada)

**Files:**
- Modify: `QuickHireButton.swift`, `PrestigeButton.swift`, `ActiveBonusBar.swift`, `HUDView.swift` (sólo trazos)

Sólo tonos de borde (ink→tono hundido del relleno de cada uno) para que la
pantalla principal hable el mismo idioma de materiales. **Geometría intacta**:
`capsuleHeight`, `barHeight`, platos, spacing — nada de eso se toca.

- [ ] **Step 1:** aplicar, compilar, commit `feat(hud): bordes tono-sobre-tono, geometría intacta`

### Task 12 (fase C): verificación completa + capturas + doc de sesión + merge

- [ ] **Step 1:** receta HANDOFF §6 EN EL WORKTREE: EconomyKit `swift test`,
  `xcodegen generate`, unit ANTES que UI, simulador propio por UDID,
  `-parallel-testing-enabled NO`. Números esperados: EconomyKit 200 · app ~370
  · UI 44 (los de la última sesión; el conteo exacto puede haberse movido con
  la sesión paralela del dueño).
- [ ] **Step 2:** instalar y lanzar con
  `--uitest-reset --uitest-skip-tutorial --uitest-coins --uitest-seen-types --uitest-unlock-tower --uitest-skins --uitest-daily-streak --uitest-achievements`,
  capturar las 13 pantallas, compararlas contra las 4 referencias, corregir lo
  que desentone (ronda de fixes con su commit).
- [ ] **Step 3:** `Docs/SESION-2026-08-17-rediseno-v3.md` con la tabla de
  estado por tarea + este plan linkeado, commiteado.
- [ ] **Step 4:** merge a `main` desde worktree temporal (protocolo de
  sesiones paralelas: jamás tocar el checkout del dueño), verificando antes
  `git log` por commits ajenos nuevos. Apagar y borrar el simulador
  (`simctl shutdown && delete` — el cierre es parte del trabajo).

## Autoevaluación contra el pedido

- "ui general" → Tasks 1-5. "pantalla principal" → Task 11 (materiales; la
  estructura es decisión cerrada del dueño). "fisujobs/upgrades/
  personalizacion/bonus/store/elevador/menu/organigrama/stats/achievments/
  settings" → Tasks 6-10 + primitivas. Legal entra con la familia del menú
  aunque no esté en la lista: comparte marco.
- "assets con selenium si hace falta" → NO hace falta: los marcos que la
  referencia pide ya están en el atlas con interior transparente; el moño y el
  marco del menú salen vectoriales (patrón de la casa: el arte puede entrar
  después por `GameIcon`/`UIArt` sin tocar código). La máquina está saturada
  (load ~500, 3 simuladores ajenos booteados) y el batch exige máquina
  quieta: correrlo hoy sería tirar reintentos. Queda anotado en el doc de
  sesión como mejora opcional (`ui_gift_bow`, marco `panel_menu`).
- "no inventes nada" → todos los materiales salen de las 4 referencias o del
  arte existente (colores muestreados del PNG).
