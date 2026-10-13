import EconomyKit
import SwiftUI
import UIKit

/// Share card vertical (bible §8): "la sátira ES el marketing". Se renderiza con
/// ImageRenderer y se comparte con UIActivityViewController — su completion
/// dispara el bonus viral (`registerShareCompleted(_:)`), cosa que ShareLink no permite.
///
/// Vive en el `PopupContainer` de la casa (E14 C15): la card es la ilustración
/// y abajo van compartir y la salida. La card misma es de T23.
struct ShareCardSheet: View {
    @Environment(GameState.self) private var gameState
    let moment: ShareMoment
    @State private var showActivity = false

    /// La vista previa a escala: la card entera cabe en el SE sin scrollear.
    private static let previewScale: CGFloat = 0.72

    var body: some View {
        PopupContainer("share.title", ribbonTint: Color("PaletteGreen"), onClose: { gameState.dismissShareCard() }) {
            ShareCardContent(moment: moment)
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
        .sheet(isPresented: $showActivity) {
            ActivityShareView(image: renderCard()) { completed in
                if completed {
                    gameState.registerShareCompleted(moment)
                }
                gameState.dismissShareCard()
            }
        }
    }

    @MainActor
    private func renderCard() -> UIImage {
        let renderer = ImageRenderer(content: ShareCardContent(moment: moment).frame(width: 540, height: 960))
        renderer.scale = 2 // 1080×1920, formato video vertical
        return renderer.uiImage ?? UIImage()
    }
}

/// El diseño de la card. El layout del póster (retrato, nombre, remate, sello)
/// es el de siempre; los materiales son los del rediseño v3 —pergamino con la
/// luz arriba, plato crema para el retrato, tinta rounded— para que la imagen
/// compartida sea una postal del juego y no un placard genérico. Ojo al elegir
/// materiales acá adentro: esto lo dibuja ImageRenderer, así que todo es
/// vectorial y de paleta, sin arte del atlas que pueda faltar en el render.
private struct ShareCardContent: View {
    let moment: ShareMoment

    private var headline: String {
        switch moment {
        case .newCharacter(let type), .god(let type): type.localizedName.uppercased()
        case .newFloor(let floorID): TowerNaming.floorName(for: floorID).uppercased()
        case .reincarnation(let level): String(localized: "share.card.reincarnation.title \(String(level))").uppercased()
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

    private var symbolName: String {
        switch moment {
        case .newCharacter(let type), .god(let type):
            type.spritePlaceholder.hasPrefix("sf:") ? String(type.spritePlaceholder.dropFirst(3)) : "person.fill"
        case .newFloor: "building.2.fill"
        case .reincarnation: "arrow.triangle.2.circlepath"
        }
    }

    var body: some View {
        ZStack {
            // El interior de panel v3 (el patrón de `PanelBackground`): el
            // gradiente amarillo→naranja anterior era del placeholder y no
            // pertenecía a ninguna pantalla del juego rediseñado.
            Color("PaletteParchment")
            LinearGradient(
                colors: [
                    Color.white.opacity(0.35),
                    .clear,
                    Color("PaletteBrown").opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: Tokens.s16) {
                Spacer()
                // `resizable` y no font fijo de 110: hay placeholders más
                // anchos que altos (box.truck, banknote) que con font se
                // salían del plato; encajado ocupa ~2/3 del plato, el mismo
                // reparto glifo/plato que usa el HUD.
                Image(systemName: symbolName)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.bold)
                    .foregroundStyle(Color("PaletteInk"))
                    .frame(width: 116, height: 116)
                    .frame(width: 176, height: 176)
                    .background(portraitPlate)
                Text(verbatim: headline)
                    .font(.system(size: 34, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color("PaletteInk"))
                caption
                    .font(Tokens.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color("PaletteInk").opacity(0.8))
                Spacer()
                Text(verbatim: "FisuEvolution")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk").opacity(0.6))
                    .padding(.bottom, Tokens.s16)
            }
            .padding(Tokens.s24)
        }
    }

    /// El plato de retrato v3, en grande: es el héroe del póster, así que
    /// lleva el radio y el borde de tarjeta (18 / brown 0.55 a 2 pt) y no los
    /// del plato chico de icono.
    private var portraitPlate: some View {
        RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
            .fill(Color("PaletteCream"))
            .overlay(
                RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                    .strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

/// UIActivityViewController con completion real (ShareLink no la expone).
private struct ActivityShareView: UIViewControllerRepresentable {
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
