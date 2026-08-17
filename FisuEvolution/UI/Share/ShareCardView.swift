import EconomyKit
import SwiftUI
import UIKit

/// Share card vertical (bible §8): "la sátira ES el marketing". Se renderiza con
/// ImageRenderer y se comparte con UIActivityViewController — su completion
/// dispara el bonus viral (`registerShareCompleted`), cosa que ShareLink no permite.
struct ShareCardSheet: View {
    @Environment(GameState.self) private var gameState
    let subject: CharacterType
    @State private var showActivity = false

    var body: some View {
        VStack(spacing: Tokens.s16) {
            ShareCardContent(subject: subject)
                .frame(width: 270, height: 480)
                .clipShape(RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous))
                // El contorno de tarjeta v3 va en la VISTA PREVIA y no dentro
                // del contenido: la imagen exportada sale a sangre completa,
                // así que este marco es chrome de la hoja, no del póster.
                .overlay(
                    RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
                        .strokeBorder(Color("PaletteBrown").opacity(0.55), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

            ActionPill(
                titleKey: "share.button",
                systemImage: "square.and.arrow.up",
                // Azul y no el verde de las acciones: compartir siempre fue
                // azul en esta hoja y ese color es parte de su identidad; lo
                // que se alinea al v3 es el material (cápsula caramelo con el
                // borde del mismo tono hundido, vía `PillBackground`).
                tint: Color("PaletteBlue"),
                identifier: "share.button",
                action: { showActivity = true }
            )

            // La salida silenciosa no compite con el CTA: texto tinta pelado,
            // sin cápsula, conservando el ancho de toque completo que tenía el
            // `.bordered` al que reemplaza.
            Button {
                gameState.dismissShareCard()
            } label: {
                Text("share.skip")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk").opacity(0.65))
                    .padding(.vertical, Tokens.s8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(Tokens.s24)
        .presentationDetents([.large])
        // El interior pergamino-con-luz de `PanelBackground`, sin marco de
        // arte: no hay un panel del atlas para esta hoja y los marcos traen
        // ornamento arriba que pide insets medidos — acá el cuadro es la
        // propia tarjeta. Va como fondo de presentación porque el contenido
        // no llena la hoja: un `.background` común dejaría el pergamino
        // recortado al tamaño del VStack.
        .presentationBackground {
            ZStack {
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
            }
        }
        .sheet(isPresented: $showActivity) {
            ActivityShareView(image: renderCard()) { completed in
                if completed {
                    gameState.registerShareCompleted()
                }
                gameState.dismissShareCard()
            }
        }
    }

    @MainActor
    private func renderCard() -> UIImage {
        let renderer = ImageRenderer(content: ShareCardContent(subject: subject).frame(width: 540, height: 960))
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
    let subject: CharacterType

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
                Text(verbatim: subject.displayName.uppercased())
                    .font(.system(size: 34, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color("PaletteInk"))
                Text("share.card.caption \(subject.displayName)")
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

    private var symbolName: String {
        subject.spritePlaceholder.hasPrefix("sf:") ? String(subject.spritePlaceholder.dropFirst(3)) : "person.fill"
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
