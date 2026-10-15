import SwiftUI

/// Reencarnar, como solapa de la barra de abajo (C18; ver `BarFlaps`), hecho
/// billete de dólar blue (E14b B28, diseño B): celeste con guarda y esquinas
/// comidas, el sello del blue (`ui_dolar_blue`) saliendo por la esquina de arriba
/// a la derecha, «Reencarnar» en blanco con contorno ink y la meta en una placa
/// crema. Tiene destellos y aletea cada tanto; cuando ya se puede reencarnar,
/// brilla más. Los dos botones se leen como un par: a la izquierda lo que
/// comprás, a la derecha lo que cobrás.
struct PrestigeButton: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () -> Void

    // La medida del texto, a la vista para el unit de geometría: el título y la
    // placa se achican hasta su `…MinScale` y tienen que entrar en el ancho que
    // les deja la solapa.
    static let titleSize: CGFloat = 15
    static let metaSize: CGFloat = 10.5
    static let titleMinScale: CGFloat = 0.6
    static let metaMinScale: CGFloat = 0.5
    /// Aire a la izquierda del texto y a la derecha de la placa.
    static let textPadding: CGFloat = 10
    /// Lo que se come el sello del blue a la derecha del título.
    static let medallionZone: CGFloat = 30

    /// El ancho que tiene el título dentro de una solapa de `lane` pt.
    static func titleWidth(lane: CGFloat) -> CGFloat { max(0, lane - textPadding * 2 - medallionZone) }
    /// El ancho que tiene el texto de la placa dentro de una solapa de `lane` pt.
    static func metaWidth(lane: CGFloat) -> CGFloat { max(0, lane - textPadding * 2 - 10) }

    var body: some View {
        // Desde el piso del teaser ("al llegar a lujo", dueño 2026-08-28) el
        // botón EXISTE aunque no haya blue por cobrar: enseña la mecánica y
        // muestra el camino. La hoja que abre sabe contar los dos estados.
        // Con el piso móvil, también aunque falte la pared: dice la meta.
        if gameState.prestigeAvailable || gameState.prestigeTeaser || gameState.prestigePreview.isBlockedByWall {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            bill
        }
        .buttonStyle(.plain)
        // ⚠️ Mismo patrón —y misma razón— que `QuickHireButton`: un `Button` de
        // SwiftUI publica el contenido de su label como hijos pase lo que pase,
        // así que sin esto el número de blue entra al árbol de AX como un
        // `StaticText` suelto. `accessibilityRepresentation` es la única forma
        // que saca los hijos y deja el botón tocable (las otras cuatro están
        // medidas y anotadas allá).
        .accessibilityRepresentation {
            Color.clear
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(spokenLabel)
        }
        // El identifier va DESPUÉS de la representación: puesto arriba se va con
        // lo que reemplaza y `app.buttons["hud.prestige"]` no encuentra nada.
        .accessibilityIdentifier("hud.prestige")
    }

    /// Se puede reencarnar con ganancia: el billete brilla más.
    private var glowing: Bool { gameState.prestigePreview.isWorthIt }

    private var bill: some View {
        let moves = !reduceMotion
        return PulseClock(interval: glowing ? 2.6 : 4.4, active: moves) { tick in
            billFace
                .keyframeAnimator(initialValue: 0.0, trigger: tick) { view, flutter in
                    view.rotationEffect(.degrees(flutter), anchor: .bottomTrailing)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-2.5, duration: 0.18)
                        CubicKeyframe(1.0, duration: 0.18)
                        CubicKeyframe(-1.0, duration: 0.16)
                        CubicKeyframe(0.0, duration: 0.16)
                    }
                }
        }
        .overlay(alignment: .topTrailing) {
            // El sello sale por la esquina: el único que se anima poco.
            Circle()
                .fill(Color("PaletteCream"))
                .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
                .overlay(BlueIcon(size: 22))
                .frame(width: 30, height: 30)
                .offset(x: 4, y: -12)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            TwinkleView(size: 12, delay: 0.4, animated: moves).offset(x: -3, y: -5)
        }
        .overlay(alignment: .bottomTrailing) {
            TwinkleView(size: 10, delay: 1.5, animated: moves).offset(x: -34, y: -4)
        }
        .shadow(color: Color("PaletteYellow").opacity(glowing ? 0.9 : 0), radius: glowing ? 7 : 0)
        .rotationEffect(.degrees(2))
        .foregroundStyle(Color("PaletteInk"))
        .dynamicTypeSize(...DynamicTypeSize.large)
        .frame(maxWidth: .infinity)
        .frame(height: GameTabBar.flapHeight)
        .contentShape(Rectangle())
    }

    private var billFace: some View {
        ZStack(alignment: .topLeading) {
            BillPaper(glowing: glowing)
            VStack(alignment: .leading, spacing: 2) {
                InkOutlinedText(text: Text("prestige.button")
                    .font(.system(size: Self.titleSize, weight: .black, design: .rounded)))
                    .lineLimit(1)
                    .minimumScaleFactor(Self.titleMinScale)
                    .padding(.trailing, Self.medallionZone)
                // El blue que te llevás es lo que hace que valga la pena
                // tocarlo. Sin blue todavía (el teaser), el renglón dice
                // cuánto camino hay hecho hacia el primero: un objetivo,
                // no una ganancia. Con el "+" delante, porque acá el número
                // es una ganancia y no un precio.
                Text(verbatim: secondLine)
                    .font(.system(size: Self.metaSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(Self.metaMinScale)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color("PaletteCream"), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color("PaletteInk"), lineWidth: 1.8))
            }
            .padding(.leading, Self.textPadding)
            .padding(.trailing, Self.textPadding)
            .padding(.top, 4)
            .padding(.bottom, GameTabBar.flapOverlap + 3)
        }
    }

    /// La segunda línea de la solapa: "+N" con blue por cobrar, o el porcentaje
    /// del camino al próximo en el teaser (verbatim: un número con % no
    /// necesita clave).
    private var secondLine: String {
        let preview = gameState.prestigePreview
        if let goal = preview.wallGoalShortText { return goal }
        return preview.isWorthIt
            ? "+\(preview.blueGained)"
            : preview.nextBlueProgress.formatted(.percent.precision(.fractionLength(0)))
    }

    /// "Reencarnar +12 blue" en una sola frase: VoiceOver no debería tener que
    /// juntar dos elementos para saber qué hace el botón.
    ///
    /// Se compone de dos claves que YA existen en vez de estrenar una: el
    /// catálogo se reescribe entero al primer build de Xcode y deja un diff de
    /// miles de líneas, así que no se lo toca por un string que se puede armar.
    ///
    /// ⚠️ El blue va como `String` a propósito: `prestige.blue.gain` está
    /// declarada con `%@` y interpolarla con un `Int` la manda como `%lld`, el
    /// lookup falla y en pantalla sale la clave cruda (trampa 5 del HANDOFF, que
    /// ya pasó dos veces).
    private var spokenLabel: Text {
        let preview = gameState.prestigePreview
        if let goal = preview.wallGoalText { return Text("prestige.button") + Text(verbatim: ", \(goal)") }
        return preview.isWorthIt
            ? Text("prestige.button")
                + Text(verbatim: " ")
                + Text("prestige.blue.gain \(String(preview.blueGained))")
            : Text("prestige.button") + Text(verbatim: " \(secondLine)")
    }
}
