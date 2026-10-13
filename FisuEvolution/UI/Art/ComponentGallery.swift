import SwiftUI

/// La vista de muestra de los componentes base de E14 (T9), sólo en DEBUG: se
/// abre con `--debug-componentes` (y `--debug-componentes-popup` para arrancar
/// con el popup largo abierto). No es una pantalla del juego: es la vidriera
/// donde se miran y se capturan los componentes antes de migrar pantallas.
struct ComponentGalleryOverlay: View {
    var body: some View {
        #if DEBUG
        if ComponentGallery.isRequested {
            ComponentGallery()
        }
        #else
        EmptyView()
        #endif
    }
}

#if DEBUG
struct ComponentGallery: View {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--debug-componentes") }
    }

    private enum Sample: String, Identifiable {
        case short, long
        var id: String { rawValue }
    }

    @State private var popup: Sample? = ProcessInfo.processInfo.arguments.contains("--debug-componentes-popup")
        ? .long : nil

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.s16) {
                SectionHeader(verbatim: "GameButton")
                buttons
                SectionHeader(verbatim: "CornerSeal")
                seals
                SectionHeader(verbatim: "Estados")
                states
                SectionHeader(verbatim: "RewardIllustration")
                rewards
                SectionHeader(verbatim: "PopupContainer")
                HStack(spacing: Tokens.s8) {
                    GameButton(verbatim: "Corto", role: .free, medallion: .glyph(.gift), size: .compact,
                               identifier: "gallery.popup.short") { popup = .short }
                    GameButton(verbatim: "Largo", role: .coins, medallion: .glyph(.package), size: .compact,
                               identifier: "gallery.popup.long") { popup = .long }
                }
            }
            .padding(Tokens.s16)
        }
        .background(
            LinearGradient(colors: [Color("PaletteBlue").lifted(0.5), Color("PaletteGreen").lifted(0.3)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
        .gamePopup(item: $popup, dismissOnVeilTap: true) { sample in
            switch sample {
            case .short: shortPopup
            case .long: longPopup
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: Tokens.s8) {
            HStack(spacing: Tokens.s8) {
                GameButton(verbatim: "¡Cobrar!", role: .free, identifier: "gallery.free") {}
                GameButton(verbatim: "Ver video", role: .video, identifier: "gallery.video") {}
            }
            HStack(spacing: Tokens.s8) {
                GameButton(verbatim: "1,2K", role: .coins, strikeText: "2,4K", identifier: "gallery.coins") {}
                GameButton(verbatim: "40", role: .blue, identifier: "gallery.blue") {}
            }
            HStack(spacing: Tokens.s8) {
                GameButton(verbatim: "No, gracias", role: .neutral, identifier: "gallery.neutral") {}
                GameButton(verbatim: "9,9M", role: .coins, available: false, identifier: "gallery.short") {}
            }
            HStack(spacing: Tokens.s8) {
                GameButton(verbatim: "Ponérsela", role: .free, size: .compact, identifier: "gallery.compact") {}
                GameButton(verbatim: "×2", role: .video, size: .compact, identifier: "gallery.compact.video") {}
                GameButton(verbatim: "Ir", role: .blue, medallion: .none, size: .compact,
                           identifier: "gallery.compact.blue") {}
            }
            GameButton(verbatim: "¡Abrir el paquete!", role: .free, medallion: .glyph(.package),
                       fullWidth: true, identifier: "gallery.full") {}
        }
    }

    private var seals: some View {
        HStack(alignment: .top, spacing: Tokens.s12) {
            CornerSeal(glyph: .package, state: .ready, caption: .text("×3"), identifier: "gallery.seal.ready",
                       accessibilityLabel: Text(verbatim: "Paquete")) {}
            CornerSeal(glyph: .wheel, tint: Color("PalettePink"), state: .running, caption: .timer("12:04"),
                       identifier: "gallery.seal.running", accessibilityLabel: Text(verbatim: "Ruleta")) {}
            CornerSeal(glyph: .chest, state: .locked, caption: .text("Piso 3"), identifier: "gallery.seal.locked",
                       accessibilityLabel: Text(verbatim: "Cofre")) {}
            CornerSeal(glyph: .offerMoving, tint: Color("PaletteBlue"), state: .done,
                       identifier: "gallery.seal.done", accessibilityLabel: Text(verbatim: "Oferta")) {}
        }
    }

    private var states: some View {
        VStack(spacing: Tokens.s8) {
            ForEach(ProgressState.allCases, id: \.self) { state in
                GameCard(style: state.cardStyle(), contentDimsWhenLocked: false) {
                    HStack(spacing: Tokens.s12) {
                        RewardIllustration(kind: .wheelSpin, size: 36, spinsRays: false)
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: Tokens.s4) {
                            Text(verbatim: "La Ruleta").font(Tokens.body).foregroundStyle(Color("PaletteInk"))
                            StateTag(state: state, text: Self.stateText(state))
                        }
                        Spacer(minLength: 0)
                        if state == .ready {
                            GameButton(verbatim: "Girar", role: .free, size: .compact, identifier: "gallery.row") {}
                        }
                    }
                }
            }
        }
    }

    private static func stateText(_ state: ProgressState) -> String {
        switch state {
        case .ready: "¡Lista para girar!"
        case .running: "Vuelve en 12 min"
        case .locked: "Te faltan 40 blue"
        case .done: "Girada hoy"
        }
    }

    private var rewards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: Tokens.s8)], spacing: Tokens.s8) {
            ForEach(RewardKind.allCases, id: \.self) { kind in
                VStack(spacing: 0) {
                    RewardIllustration(kind: kind, size: 48)
                    Text(verbatim: kind.rawValue)
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .padding(Tokens.s8)
        .background(RoundedRectangle(cornerRadius: CardMaterials.cornerRadius).fill(Color("PaletteCream")))
    }

    private var shortPopup: some View {
        PopupContainer(verbatim: "¡Un regalo!", ribbonTint: Color("PaletteGreen"), onClose: { popup = nil }) {
            RewardIllustration(kind: .coins, size: 120)
            Text(verbatim: "+1,2K").font(Tokens.display).foregroundStyle(Color("PaletteInk"))
            Text(verbatim: "El Fisura te deja unas monedas.")
                .font(Tokens.body).foregroundStyle(Color("PaletteInk")).multilineTextAlignment(.center)
        } actions: {
            GameButton(verbatim: "¡Cobrar!", role: .free, identifier: "gallery.popup.claim") { popup = nil }
            GameButton(verbatim: "×2", role: .video, identifier: "gallery.popup.double") { popup = nil }
        }
    }

    private var longPopup: some View {
        PopupContainer(verbatim: "El Paquete de la Aduana", onClose: { popup = nil }) {
            RewardIllustration(kind: .mystery, size: 140)
            Text(verbatim: "Puede traer cualquiera de estas cosas:")
                .font(Tokens.body).foregroundStyle(Color("PaletteInk")).multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: Tokens.s8) {
                ForEach(RewardKind.allCases, id: \.self) { kind in
                    RewardIllustration(kind: kind, size: 44, spinsRays: false)
                }
            }
        } actions: {
            GameButton(verbatim: "Abrir gratis", role: .free, identifier: "gallery.popup.free") { popup = nil }
            GameButton(verbatim: "Abrir 3 con video", role: .video, identifier: "gallery.popup.video") { popup = nil }
            GameButton(verbatim: "Después", role: .neutral, identifier: "gallery.popup.later") { popup = nil }
        }
    }
}
#endif
