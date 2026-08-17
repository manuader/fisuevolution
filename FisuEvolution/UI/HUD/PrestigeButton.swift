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

    /// El mismo alto que la cápsula de contratar, derivado y no copiado: las dos
    /// comparten fila y con literales sueltos se desalinean el día que una
    /// cambie. Ver la nota de `QuickHireButton.capsuleHeight`, que explica por
    /// qué el número existe y qué lo invalida (Dynamic Type, no un rediseño).
    static let capsuleHeight: CGFloat = QuickHireButton.capsuleHeight

    var body: some View {
        if gameState.prestigeAvailable {
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
                        .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                    OroIcon(size: 22)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text("prestige.button")
                        .font(Tokens.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // El ORO que te llevás es lo que hace que valga la pena
                    // tocarlo, y es el gemelo del precio del otro botón.
                    HStack(spacing: 5) {
                        OroIcon(size: 20)
                        // Con el "+" delante: del otro lado el número es un
                        // PRECIO y acá es una ganancia, y a igual tipografía eso
                        // es lo único que los distingue.
                        Text(verbatim: "+\(gameState.prestigePreview.oroGained)")
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
                Capsule()
                    .fill(Color("PalettePink"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
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
        Text("prestige.button")
            + Text(verbatim: " ")
            + Text("prestige.oro.gain \(String(gameState.prestigePreview.oroGained))")
    }
}
