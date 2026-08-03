import SwiftUI

/// Menú de configuración: toggles de sonido y música (con arte propio) que
/// controlan el AudioManager de verdad (volúmenes persistidos). Panel con arte
/// `panel_config` (fallback crema si todavía no se generó) + botón cerrar.
struct ConfigView: View {
    @Environment(AudioManager.self) private var audio
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GamePanel(art: "panel_config",
                  insets: EdgeInsets(top: 76, leading: 26, bottom: 28, trailing: 26)) {
            VStack(spacing: 20) {
                Text(verbatim: "Configuración")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color("PaletteInk"))
                settingRow("Sonido", isOn: audio.sfxVolume > 0) { on in
                    audio.sfxVolume = on ? 1 : 0
                }
                settingRow("Música", isOn: audio.musicVolume > 0) { on in
                    audio.musicVolume = on ? 1 : 0
                }
                Spacer(minLength: 0)
            }
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { dismiss() }.padding(18)
        }
        .padding(16)
        .presentationDetents([.fraction(0.42)])
    }

    private func settingRow(_ label: String, isOn: Bool, set: @escaping (Bool) -> Void) -> some View {
        HStack {
            Text(verbatim: label)
                .font(.headline)
                .foregroundStyle(Color("PaletteInk"))
            Spacer()
            Button { set(!isOn) } label: { artToggle(isOn) }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: label))
                .accessibilityValue(Text(verbatim: isOn ? "on" : "off"))
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder private func artToggle(_ isOn: Bool) -> some View {
        // Toggle vectorial: el PNG `ui_toggle_on` quedó sin relleno verde (rembg),
        // así que on/off eran indistinguibles. GameToggle garantiza el estado.
        GameToggle(isOn: isOn, width: 66, height: 38)
    }
}
