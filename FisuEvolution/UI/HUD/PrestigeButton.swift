import SwiftUI

/// Reencarnar, como solapa de la barra de abajo (C18; ver `BarFlaps`): el ícono
/// del blue y su estado, en el mismo material que la solapa de Contratar con el
/// tinte del prestigio. Los dos se leen como un par: a la izquierda lo que
/// comprás, a la derecha lo que cobrás.
struct PrestigeButton: View {
    @Environment(GameState.self) private var gameState
    let action: () -> Void

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
            HStack(spacing: 5) {
                BlueIcon(size: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text("prestige.button")
                        .font(Tokens.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    // El blue que te llevás es lo que hace que valga la pena
                    // tocarlo. Sin blue todavía (el teaser), el renglón dice
                    // cuánto camino hay hecho hacia el primero: un objetivo,
                    // no una ganancia. Con el "+" delante, porque acá el número
                    // es una ganancia y no un precio.
                    Text(verbatim: secondLine)
                        .font(Tokens.body)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .foregroundStyle(Color("PaletteInk"))
            .dynamicTypeSize(...DynamicTypeSize.large)
            .barFlapSurface(tint: Color("PalettePink"))
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
