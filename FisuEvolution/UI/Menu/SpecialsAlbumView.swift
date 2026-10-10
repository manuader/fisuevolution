import SwiftUI

/// **Álbum de especiales** (PLAN-v2 E4): los diez personajes raros, los que
/// tenés con su retrato y lo que te dan, los que faltan en silueta. Se empuja
/// desde la Oficina central como las otras cuatro pantallas del menú.
struct SpecialsAlbumView: View {
    @Environment(GameState.self) private var gameState
    /// Cierra la HOJA entera (ver `MenuView`: `dismiss` acá desapilaría).
    let close: () -> Void

    var body: some View {
        let entries = gameState.albumEntries
        ScrollView {
            VStack(spacing: Tokens.s12) {
                Text("album.progress \(entries.filter(\.owned).count) \(entries.count)")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk").opacity(0.8))
                    .accessibilityIdentifier("album.progress")
                // `Grid` de filas y no `LazyVGrid`: son diez tarjetas contadas y
                // tienen que existir en el árbol de accesibilidad sin scrollear
                // (la misma razón que la grilla de `MenuView`).
                Grid(horizontalSpacing: Tokens.s12, verticalSpacing: Tokens.s12) {
                    ForEach(Array(stride(from: 0, to: entries.count, by: 2)), id: \.self) { index in
                        // Arriba: con el chiste de uno y no del otro, las dos
                        // de una fila no miden lo mismo.
                        GridRow(alignment: .top) {
                            card(entries[index])
                            if index + 1 < entries.count { card(entries[index + 1]) } else { Color.clear }
                        }
                    }
                }
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.top, Tokens.s12)
            .padding(.bottom, Tokens.s24)
        }
        .panelSheet { PanelTitleBanner(titleKey: "album.title") }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) }
        }
    }

    private func card(_ entry: AlbumEntry) -> some View {
        GameCard(style: entry.owned ? .highlighted(Color("PaletteYellow")) : .normal) {
            VStack(spacing: Tokens.s4) {
                portrait(entry)
                    .frame(width: 84, height: 84)
                Text(entry.owned ? LocalizedStringKey(entry.nameKey) : "album.unknown")
                    .font(Tokens.body)
                    .foregroundStyle(Color("PaletteInk"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if entry.owned {
                    Text(verbatim: entry.effectText)
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteGreen").deepened(0.3))
                    Text(LocalizedStringKey(entry.flavorKey))
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("album.locked \(entry.minTier)")
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        // El estado va en el id y no en un valor hablado: VoiceOver ya dice el
        // nombre o "Por descubrir", y un "owned" crudo se leería en inglés.
        .accessibilityIdentifier("album.card.\(entry.id).\(entry.owned ? "owned" : "locked")")
    }

    @ViewBuilder
    private func portrait(_ entry: AlbumEntry) -> some View {
        if let manifest = gameState.content?.manifest,
           let image = VisitorArt.image(for: entry.id, pose: .canonical, manifest: manifest) {
            // Los que faltan, en silueta: se sabe que existen, no cómo son.
            image.resizable().scaledToFit()
                .colorMultiply(entry.owned ? .white : .black)
                .opacity(entry.owned ? 1 : 0.35)
        } else {
            Image(systemName: entry.owned ? "star.circle.fill" : "questionmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(entry.owned ? Color("PaletteYellow") : Color("PaletteInk").opacity(0.3))
        }
    }
}
