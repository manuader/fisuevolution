import SwiftUI

/// El ítem que un evento de compra destaca al abrir la Tienda o Mejoras (C25). La pantalla de
/// destino lo publica por entorno; cada fila se encarga de sí misma.
private struct ShopFocusItemKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private struct ShopFocusScrollKey: EnvironmentKey {
    static let defaultValue: (@MainActor (String) -> Void)? = nil
}

extension EnvironmentValues {
    /// El id de la fila destacada, o `nil`.
    var shopFocusItem: String? {
        get { self[ShopFocusItemKey.self] }
        set { self[ShopFocusItemKey.self] = newValue }
    }

    /// Lleva la lista hasta una fila.
    var shopFocusScroll: (@MainActor (String) -> Void)? {
        get { self[ShopFocusScrollKey.self] }
        set { self[ShopFocusScrollKey.self] = newValue }
    }
}

/// Marca una fila como destino de scroll y, si es la destacada, la lleva al centro y le pone un
/// marco que late unos segundos. Con Reduce Motion el marco queda quieto.
struct ShopFocusHighlight: ViewModifier {
    let id: String
    var cornerRadius: CGFloat = CardMaterials.cornerRadius

    @Environment(\.shopFocusItem) private var focused
    @Environment(\.shopFocusScroll) private var scroll
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var visible = false

    private static let highlightSeconds = 6.0

    func body(content: Content) -> some View {
        content
            .id(id)
            .overlay {
                if visible {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color("PaletteOrange"), lineWidth: 4)
                        .opacity(pulse ? 1 : 0.45)
                        .scaleEffect(pulse && !reduceMotion ? 1.02 : 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .task(id: focused == id) {
                guard focused == id else {
                    visible = false
                    return
                }
                visible = true
                try? await Task.sleep(for: .milliseconds(350))
                scroll?(id)
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
                } else {
                    pulse = true
                }
                try? await Task.sleep(for: .seconds(Self.highlightSeconds))
                withAnimation(.easeOut(duration: 0.3)) { visible = false }
            }
    }
}

extension View {
    func shopFocus(id: String, cornerRadius: CGFloat = CardMaterials.cornerRadius) -> some View {
        modifier(ShopFocusHighlight(id: id, cornerRadius: cornerRadius))
    }
}
