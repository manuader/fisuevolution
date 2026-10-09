import SwiftUI

/// La confirmación de la casa (PLAN-v2 E3): una `PanelCard` sobre un velo, con
/// el título, el detalle y dos salidas. Reemplaza a la alerta del sistema, que
/// era lo único del juego que se veía de otra app. La reusa el reset de E9.
///
/// Va como `.overlay` de la pantalla que pregunta y no como otra hoja: una hoja
/// sobre otra apila dos marcos, y el arrastre podría cerrarla a medias.
struct GameConfirmCard: View {
    let titleKey: LocalizedStringKey
    let message: Text
    let confirmTitleKey: LocalizedStringKey
    let confirmSystemImage: String
    /// Rosa para lo destructivo (despedir, resetear), como la firma de la casa.
    var confirmTint: Color = Color("PalettePink")
    let cancelTitleKey: LocalizedStringKey
    /// Los identificadores de las dos salidas; la reset de E9 usa los de siempre.
    var acceptIdentifier = "confirm.accept"
    var cancelIdentifier = "confirm.cancel"
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)
            PanelCard {
                VStack(spacing: Tokens.s12) {
                    Text(titleKey)
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                    message
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk").opacity(0.75))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    ActionPill(
                        titleKey: confirmTitleKey,
                        systemImage: confirmSystemImage,
                        tint: confirmTint,
                        identifier: acceptIdentifier,
                        action: onConfirm
                    )
                    // La salida silenciosa no compite con la acción: texto
                    // tinta pelado, como "Ahora no" en la tarjeta de compartir.
                    Button(action: onCancel) {
                        Text(cancelTitleKey)
                            .font(Tokens.body)
                            .foregroundStyle(Color("PaletteInk").opacity(0.75))
                            .padding(.vertical, Tokens.s8)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(cancelIdentifier)
                }
            }
            .frame(maxWidth: 360)
            .padding(Tokens.s24)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }
}
