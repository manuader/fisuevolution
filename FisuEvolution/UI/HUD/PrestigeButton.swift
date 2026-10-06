import SwiftUI

/// Reencarnar, como cápsula del sistema visual de la casa.
///
/// ⚠️ **Era el último `.buttonStyle(.borderedProminent)` de la pantalla
/// principal**, y por eso desentonaba: un botón del sistema —esquinas de iOS,
/// sin contorno, sin sombra— al lado de cápsulas con borde ink de 3 pt. No era
/// un problema de color sino de material.
///
/// Es el **espejo** de `QuickHireButton`, a propósito: misma cápsula, mismo
/// borde, misma sombra, mismo alto y la misma composición icono+dos líneas. Los
/// dos comparten fila y dicen lo mismo desde los dos extremos —a la izquierda lo
/// que comprás, a la derecha lo que cobrás—, así que tienen que leerse como un
/// par y no como dos botones que quedaron cerca.
struct PrestigeButton: View {
    @Environment(GameState.self) private var gameState
    let action: () -> Void

    var body: some View {
        // Desde el piso del teaser ("al llegar a lujo", dueño 2026-08-28) el
        // botón EXISTE aunque no haya ORO por cobrar: enseña la mecánica y
        // muestra el camino. La hoja que abre sabe contar los dos estados.
        if gameState.prestigeAvailable || gameState.prestigeTeaser {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: Tokens.s8) {
                // Círculo crema + borde ink + glifo tintado: el mismo material
                // que los iconos del HUD. Le da a la cápsula el peso visual que
                // del otro lado aporta la carita del personaje, así las dos
                // tienen la misma densidad.
                ZStack {
                    Circle()
                        .fill(Color("PaletteCream"))
                        .overlay(Circle().strokeBorder(Color("PalettePink").deepened(0.3), lineWidth: 2.5))
                    OroIcon(size: 22)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text("prestige.button")
                        .font(Tokens.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // El ORO que te llevás es lo que hace que valga la pena
                    // tocarlo, y es el gemelo del precio del otro botón. Sin
                    // ORO todavía (el teaser), el renglón dice cuánto camino
                    // hay hecho hacia el primero: un objetivo, no una ganancia.
                    HStack(spacing: 5) {
                        OroIcon(size: 20)
                        // Con el "+" delante: del otro lado el número es un
                        // PRECIO y acá es una ganancia, y a igual tipografía eso
                        // es lo único que los distingue.
                        Text(verbatim: secondLine)
                            .font(Tokens.body)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
            .padding(.horizontal, Tokens.s16)
            .padding(.vertical, Tokens.s8)
            .background(
                // El mismo material caramelo que QuickHire, en el rosa del
                // prestigio.
                PillBackground(fill: Color("PalettePink"))
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // ⚠️ Mismo patrón —y misma razón— que `QuickHireButton`: un `Button` de
        // SwiftUI publica el contenido de su label como hijos pase lo que pase,
        // así que sin esto el número de ORO entra al árbol de AX como un
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

    /// La segunda línea de la cápsula: "+N" con ORO por cobrar, o el porcentaje
    /// del camino al próximo en el teaser (verbatim: un número con % no
    /// necesita clave).
    private var secondLine: String {
        let preview = gameState.prestigePreview
        return preview.isWorthIt
            ? "+\(preview.oroGained)"
            : preview.nextOroProgress.formatted(.percent.precision(.fractionLength(0)))
    }

    /// "Reencarnar +12 ORO" en una sola frase: VoiceOver no debería tener que
    /// juntar dos elementos para saber qué hace el botón.
    ///
    /// Se compone de dos claves que YA existen en vez de estrenar una: el
    /// catálogo se reescribe entero al primer build de Xcode y deja un diff de
    /// miles de líneas, así que no se lo toca por un string que se puede armar.
    ///
    /// ⚠️ El ORO va como `String` a propósito: `prestige.oro.gain` está
    /// declarada con `%@` y interpolarla con un `Int` la manda como `%lld`, el
    /// lookup falla y en pantalla sale la clave cruda (trampa 5 del HANDOFF, que
    /// ya pasó dos veces).
    private var spokenLabel: Text {
        let preview = gameState.prestigePreview
        return preview.isWorthIt
            ? Text("prestige.button")
                + Text(verbatim: " ")
                + Text("prestige.oro.gain \(String(preview.oroGained))")
            : Text("prestige.button") + Text(verbatim: " \(secondLine)")
    }
}
