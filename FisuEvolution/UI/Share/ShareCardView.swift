import EconomyKit
import SwiftUI
import UIKit

/// Share card vertical (bible §8): "la sátira ES el marketing". Se renderiza con
/// ImageRenderer y se comparte con UIActivityViewController — su completion
/// dispara el bonus viral (`registerShareCompleted(_:)`), cosa que ShareLink no permite.
///
/// Vive en el `PopupContainer` de la casa (E14 C15): la card es la ilustración
/// y abajo van compartir y la salida. La abre la oferta chica de un piso nuevo
/// o de una reencarnación; el personaje nuevo comparte desde su propia card.
struct ShareCardSheet: View {
    @Environment(GameState.self) private var gameState
    let moment: ShareMoment
    @State private var artwork = ShareArtwork.empty
    @State private var showActivity = false

    /// La vista previa a escala: la card entera cabe en el SE sin scrollear.
    private static let previewScale: CGFloat = 0.72

    var body: some View {
        PopupContainer("share.title", ribbonTint: Color("PaletteGreen"), onClose: { gameState.dismissShareCard() }) {
            ShareCardPreview(moment: moment, artwork: artwork)
                .frame(width: 270, height: 480)
                .clipShape(RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous))
                // El contorno de tarjeta v3 va en la VISTA PREVIA y no dentro
                // del contenido: la imagen exportada sale a sangre completa,
                // así que este marco es chrome del popup, no del póster.
                .overlay(
                    RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                        .strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .scaleEffect(Self.previewScale)
                .frame(width: 270 * Self.previewScale, height: 480 * Self.previewScale)
        } actions: {
            GameButton("share.button", role: .free, medallion: .glyph(.gift), identifier: "share.button") {
                showActivity = true
            }
            GameButton("share.skip", role: .neutral, identifier: "share.skip") {
                gameState.dismissShareCard()
            }
        }
        .task { artwork = ShareArt.artwork(for: moment, in: gameState) }
        .shareActivity(isPresented: $showActivity, moment: moment, artwork: artwork) { completed in
            if completed {
                gameState.registerShareCompleted(moment)
            }
            gameState.dismissShareCard()
        }
    }
}

/// La imagen que sale a las redes.
enum ShareCardRenderer {
    static let size = CGSize(width: 540, height: 960)

    /// 1080×1920, formato video vertical. Sin arte cargado (el popup todavía no
    /// terminó su `task`) lo carga acá: nunca sale la card vacía.
    @MainActor
    static func render(_ moment: ShareMoment, artwork: ShareArtwork, in gameState: GameState) -> UIImage {
        let art = artwork.portrait == nil && artwork.background == nil
            ? ShareArt.artwork(for: moment, in: gameState) : artwork
        return render(moment, artwork: art)
    }

    @MainActor
    static func render(_ moment: ShareMoment, artwork: ShareArtwork) -> UIImage {
        let renderer = ImageRenderer(
            content: ShareCardContent(moment: moment, artwork: artwork).frame(width: size.width, height: size.height)
        )
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }
}

/// La card entera (540×960) achicada al marco de la vista previa.
struct ShareCardPreview: View {
    let moment: ShareMoment
    let artwork: ShareArtwork

    var body: some View {
        ShareCardContent(moment: moment, artwork: artwork)
            .frame(width: ShareCardRenderer.size.width, height: ShareCardRenderer.size.height)
            .scaleEffect(270 / ShareCardRenderer.size.width, anchor: .topLeading)
            .frame(width: 270, height: 480, alignment: .topLeading)
    }
}

/// El diseño de la card (540×960): el personaje real, grande y con su skin,
/// sobre el fondo de su piso, dentro del pergamino con el marco de la casa; el
/// título del logro arriba del personaje y el logo del juego arriba de todo.
/// Lo dibuja ImageRenderer, así que todo es vectorial o `UIImage` ya cargado.
/// Si el retrato no está, el respaldo es el de la casa, nunca un SF Symbol.
struct ShareCardContent: View {
    let moment: ShareMoment
    let artwork: ShareArtwork

    private var name: String {
        switch moment {
        case .newCharacter(let type), .god(let type): type.localizedName
        case .newFloor(let floorID): TowerNaming.floorName(for: floorID)
        case .reincarnation(let level): String(localized: "share.card.reincarnation.title \(String(level))")
        }
    }

    private var caption: Text {
        switch moment {
        case .newCharacter(let type): Text("share.card.caption \(type.localizedName)")
        case .newFloor(let floorID): Text("share.card.floor \(TowerNaming.floorName(for: floorID))")
        case .reincarnation: Text("share.card.reincarnation")
        case .god: Text("share.card.god")
        }
    }

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: Tokens.s16) {
                logo
                scroll
                storeLine
            }
            .padding(.horizontal, Tokens.s24)
            .padding(.vertical, Tokens.s24)
        }
    }

    /// El fondo del piso; sin él, el pergamino liso de siempre.
    private var backdrop: some View {
        ZStack {
            Color("PaletteParchment")
            if let background = artwork.background {
                Image(uiImage: background)
                    .resizable()
                    .scaledToFill()
                LinearGradient(
                    colors: [.black.opacity(0.10), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.35), .clear, Color("PaletteBrown").opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(width: ShareCardRenderer.size.width, height: ShareCardRenderer.size.height)
        .clipped()
    }

    @ViewBuilder
    private var logo: some View {
        if let logo = artwork.logo {
            Image(uiImage: logo)
                .resizable()
                .scaledToFit()
                .frame(height: 96)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        } else {
            Text(verbatim: "FISU EVOLUTION")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Color("PaletteCream"))
                .shadow(color: .black.opacity(0.5), radius: 0, y: 3)
                .frame(height: 96)
        }
    }

    /// El pergamino con el marco de la casa: título, personaje y la frase.
    private var scroll: some View {
        VStack(spacing: Tokens.s12) {
            Text(verbatim: name.uppercased())
                .font(.system(size: 36, design: .rounded).weight(.heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            hero
            caption
                .font(.system(size: 24, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("PaletteInk").opacity(0.85))
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .padding(Tokens.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
            shape.fill(Color("PaletteParchment"))
                .overlay(shape.fill(LinearGradient(
                    colors: [Color.white.opacity(0.35), .clear, Color("PaletteBrown").opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )))
                .overlay(shape.strokeBorder(Color("PaletteBrown"), lineWidth: 6))
                .overlay(shape.inset(by: 8).strokeBorder(Color("PaletteBrown").opacity(0.35), lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
    }

    /// El personaje con los rayos detrás.
    private var hero: some View {
        ZStack {
            RayFan(rays: 16)
                .fill(Color("PaletteYellow").opacity(0.7))
                .mask {
                    RadialGradient(
                        colors: [.black, .black.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 250
                    )
                }
                .frame(width: 500, height: 500)
            portrait
                .frame(width: 360, height: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var portrait: some View {
        if let portrait = artwork.portrait {
            Image(uiImage: portrait)
                .resizable()
                .scaledToFit()
                .colorMultiply(artwork.portraitTint ?? .white)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
        } else {
            MarkDisc(mark: String(name.prefix(1)).uppercased(), fill: Color("PaletteYellow"))
                .frame(width: 260, height: 260)
        }
    }

    private var storeLine: some View {
        Text("share.card.store")
            .font(.system(size: 22, design: .rounded).weight(.heavy))
            .foregroundStyle(Color("PaletteCream"))
            .shadow(color: .black.opacity(0.6), radius: 0, y: 2)
            .frame(height: 36)
    }
}

extension View {
    /// La hoja del sistema para compartir la imagen del momento; `onFinish`
    /// dice si se completó. Es el único lugar que la presenta (el guardia de
    /// hojas la autoriza en este archivo).
    func shareActivity(
        isPresented: Binding<Bool>, moment: ShareMoment, artwork: ShareArtwork,
        onFinish: @escaping (Bool) -> Void
    ) -> some View {
        modifier(ShareActivityPresenter(isPresented: isPresented, moment: moment, artwork: artwork, onFinish: onFinish))
    }
}

private struct ShareActivityPresenter: ViewModifier {
    @Environment(GameState.self) private var gameState
    @Binding var isPresented: Bool
    let moment: ShareMoment
    let artwork: ShareArtwork
    let onFinish: (Bool) -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            ActivityShareView(image: ShareCardRenderer.render(moment, artwork: artwork, in: gameState), onFinish: onFinish)
        }
    }
}

/// UIActivityViewController con completion real (ShareLink no la expone).
struct ActivityShareView: UIViewControllerRepresentable {
    let image: UIImage
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
