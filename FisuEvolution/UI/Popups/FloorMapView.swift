import SwiftUI

/// El mapa de la torre (RF-08): un ascensor vertical con todos los pisos
/// apilados como un edificio —Dios arriba, el callejón abajo— para poder ir del
/// piso 1 al 10 de un toque en vez de subir de a uno.
///
/// La vista no sabe cuántos pisos hay ni cómo se llaman los fondos: todo llega
/// resuelto en `gameState.floorMap`, que sale de `floors[]`.
struct FloorMapView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // `boardVersion` es lo único que puede cambiar una ocupación mientras el
        // mapa está abierto; leerlo acá alcanza para que la lista no se quede
        // vieja sin observar `PlayerState`, que es lo que la UI nunca hace.
        let _ = gameState.boardVersion
        let floors = gameState.floorMap

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(floors) { entry in
                            floorRow(entry).id(entry.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    // Se abre mostrando dónde estás parado, no la punta de la
                    // torre: el mapa es para moverse desde acá.
                    guard let here = floors.first(where: \.isVisible) else { return }
                    proxy.scrollTo(here.id, anchor: .center)
                }
            }
            .background { PanelBackground(art: "panel_dialog") }
            .safeAreaInset(edge: .top) {
                PanelTitleBanner(titleKey: "map.title")
                    .padding(.top, 6)
                    .padding(.bottom, 4)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            // Sin esto la barra queda blanca de sistema contra el crema del
            // panel, que es la única superficie del juego que se ve así.
            .toolbarBackground(Color("PaletteCream"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ArtCloseButton { dismiss() } }
            }
        }
    }

    private func floorRow(_ entry: FloorMapEntry) -> some View {
        Button {
            gameState.jumpToFloor(ordinal: entry.ordinal)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                thumbnail(entry)
                VStack(alignment: .leading, spacing: 2) {
                    Text(TowerNaming.floorNameKey(for: entry.id))
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // El número de piso se interpola SIEMPRE como String: con un
                    // Int, Swift manda %lld, el lookup falla y en pantalla queda
                    // la clave cruda. Ya pasó dos veces en este repo.
                    Text("map.floor.ordinal \(String(entry.ordinal + 1))")
                        .font(.system(size: 11, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color("PaletteInk").opacity(0.6))
                }
                Spacer(minLength: 6)
                trailing(entry)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color("PaletteInk").opacity(entry.isUnlocked ? 1 : 0.45))
            .background(rowBackground(entry))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!entry.isUnlocked)
        .accessibilityIdentifier("map.floor.\(entry.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TowerNaming.floorNameKey(for: entry.id))
        .accessibilityValue(
            entry.isUnlocked
                ? Text(verbatim: "\(entry.occupied)/\(entry.capacity)")
                : Text("map.locked")
        )
    }

    @ViewBuilder
    private func trailing(_ entry: FloorMapEntry) -> some View {
        if entry.isUnlocked {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(verbatim: "\(entry.occupied)/\(entry.capacity)")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .monospacedDigit()
                }
                .accessibilityLabel(Text("map.occupancy.label"))
                if entry.isVisible {
                    Text("map.here")
                        .font(.system(size: 10, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color("PaletteBlue"))
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("map.locked")
                    .font(.system(size: 11, design: .rounded).weight(.heavy))
                    .lineLimit(1)
            }
        }
    }

    /// Miniatura del fondo REAL del piso. El puente código→arte sigue siendo el
    /// manifest: sin entrada ahí, un rectángulo neutro (igual que en la escena).
    @ViewBuilder
    private func thumbnail(_ entry: FloorMapEntry) -> some View {
        let asset = gameState.content?.manifest.backgrounds[entry.backgroundKey]
        ZStack {
            if let asset, let image = FloorThumbnail.image(named: asset) {
                image
                    .resizable()
                    .scaledToFill()
                    .saturation(entry.isUnlocked ? 1 : 0)
                    .opacity(entry.isUnlocked ? 1 : 0.5)
            } else {
                Color("PaletteInk").opacity(entry.isUnlocked ? 0.18 : 0.08)
            }
        }
        .frame(width: 86, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color("PaletteInk").opacity(entry.isUnlocked ? 0.8 : 0.3), lineWidth: 2)
        )
    }

    private func rowBackground(_ entry: FloorMapEntry) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color("PaletteCream").opacity(entry.isUnlocked ? 0.95 : 0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        entry.isVisible ? Color("PaletteBlue") : Color("PaletteInk").opacity(entry.isUnlocked ? 0.75 : 0.25),
                        lineWidth: entry.isVisible ? 3 : 2
                    )
            )
    }
}

/// Miniaturas de los fondos, cacheadas ya achicadas.
///
/// Los fondos son PNG de 1024×1024: once filas dibujando la imagen completa son
/// ~44 MB de bitmaps vivos cada vez que se abre el mapa. `preparingThumbnail`
/// deja en memoria sólo la versión chica y suelta la grande.
@MainActor
private enum FloorThumbnail {
    private static var cache: [String: Image] = [:]
    private static let side = CGSize(width: 240, height: 240)

    static func image(named assetName: String) -> Image? {
        if let cached = cache[assetName] { return cached }
        guard let full = UIImage(named: assetName),
              let small = full.preparingThumbnail(of: side) else { return nil }
        let image = Image(uiImage: small)
        cache[assetName] = image
        return image
    }
}
