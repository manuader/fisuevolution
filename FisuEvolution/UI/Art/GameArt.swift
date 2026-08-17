import SpriteKit
import SwiftUI

/// Puente atlas de SpriteKit → SwiftUI. Los assets de UI/tutorial viven en
/// `ui.atlas` (texture atlas de SpriteKit), no en el asset catalog, así que
/// `Image(named:)` no los ve. Acá se cargan como `SKTexture`/`UIImage`.
@MainActor
enum UIArt {
    private static let atlas = SKTextureAtlas(named: "ui")
    /// Nombres integrados. `SKTextureAtlas.textureNames` viene VACÍO hasta hacer
    /// preload, así que la fuente de verdad es el manifest (claves ui), seteado
    /// en el arranque con `configure`. `textureNamed()` sí carga bien la textura.
    private static var available: Set<String> = []
    private static var uiCache: [String: UIImage] = [:]
    /// Retratos de personajes: atlas parametrizable, separado del atlas UI y
    /// cacheado por `atlas/key` para que la ficha no recodifique PNGs al paginar.
    private static var characterCache: [String: UIImage] = [:]

    /// Llamado en bootstrap con `content.manifest.ui.keys` (assets integrados).
    static func configure(available names: Set<String>) {
        available = names
        uiCache.removeAll()
        characterCache.removeAll()
    }

    static func has(_ name: String) -> Bool { available.contains(name) }

    static func uiImage(_ name: String) -> UIImage? {
        guard available.contains(name) else { return nil }
        if let cached = uiCache[name] { return cached }
        let cg = atlas.textureNamed(name).cgImage()
        // Escala alta → tamaño en PUNTOS chico (~200pt). Clave para el 9-slice:
        // los capInsets se miden en puntos de la imagen; si la imagen midiera 1024pt,
        // un inset del 20% = 205pt y el botón no podría achicarse por debajo de ~410pt.
        let scale = max(1, CGFloat(cg.width) / 200)
        let image = UIImage(cgImage: cg, scale: scale, orientation: .up)
        uiCache[name] = image
        return image
    }

    /// Imagen a escala natural (para íconos: usar con `.scaledToFit()`).
    static func image(_ name: String) -> Image? {
        uiImage(name).map { Image(uiImage: $0) }
    }

    static func characterImage(atlas atlasName: String, key: String) -> Image? {
        let cacheKey = "\(atlasName)/\(key)"
        if let cached = characterCache[cacheKey] { return Image(uiImage: cached) }
        let texture = AtlasCache.atlas(named: atlasName).textureNamed(key)
        guard texture.size().width > 1, texture.size().height > 1 else { return nil }
        let cg = texture.cgImage()
        let image = UIImage(cgImage: cg, scale: max(1, CGFloat(cg.width) / 200), orientation: .up)
        characterCache[cacheKey] = image
        return Image(uiImage: image)
    }

    /// Imagen 9-slice: sólo el centro se estira, los bordes/esquinas quedan fijos.
    /// Es lo que hace que botones/burbujas/paneles no se deformen al cambiar de
    /// tamaño. `cap` = fracción del lado menor reservada como borde.
    static func nineSlice(_ name: String, cap: CGFloat = 0.3) -> Image? {
        guard let ui = uiImage(name) else { return nil }
        let inset = min(ui.size.width, ui.size.height) * cap
        return Image(uiImage: ui)
            .resizable(capInsets: EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset),
                       resizingMode: .stretch)
    }
}

/// Un panel/diálogo con arte propio: fondo crema opaco + marco decorativo 9-slice
/// por encima (no se deforma). Si el arte no existe, cae a una tarjeta crema.
struct GamePanel<Content: View>: View {
    let art: String
    var insets: EdgeInsets = EdgeInsets(top: 72, leading: 30, bottom: 34, trailing: 30)
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(insets)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color("PaletteCream"))
                        .padding(18)
                    if let frame = UIArt.nineSlice(art, cap: 0.32) {
                        frame
                    } else {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(Color("PaletteInk"), lineWidth: 3)
                    }
                }
            )
    }
}

/// Botón con arte propio (imagen sin texto) 9-slice + label encima con padding
/// generoso y auto-encogido para que el texto SIEMPRE entre. Sin arte, cae a una
/// cápsula teñida.
struct ArtButton<Label: View>: View {
    let art: String
    var tint: Color = Color("PaletteGreen")
    var minHeight: CGFloat = 60
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(background)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var background: some View {
        ZStack {
            // Respaldo teñido: garantiza un botón visible aunque el arte tenga
            // margen transparente o todavía no exista.
            Capsule().fill(tint)
            if let img = UIArt.nineSlice(art, cap: 0.17) { img }
        }
    }
}

/// Ícono de moneda (`ui_coin`); sin arte, SF Symbol teñido.
struct CoinIcon: View {
    var size: CGFloat = 26
    var body: some View {
        Group {
            if let coin = UIArt.image("ui_coin") {
                coin.resizable().scaledToFit()
            } else {
                Image(systemName: "dollarsign.circle.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(Color("PaletteYellow"))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Ícono de ORO, la moneda de reencarnación (`ui_oro`). Mismo patrón que
/// `CoinIcon`: usa el asset del pipeline cuando existe y cae a un vectorial
/// teñido mientras no esté, así el arte puede entrar sin tocar la UI.
struct OroIcon: View {
    var size: CGFloat = 26
    var body: some View {
        Group {
            if let oro = UIArt.image("ui_oro") {
                oro.resizable().scaledToFit()
            } else {
                Image(systemName: "sparkles")
                    .resizable().scaledToFit()
                    .foregroundStyle(Color("PaletteYellow"))
                    .shadow(color: Color("PaletteInk").opacity(0.35), radius: 0.5)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Botón cerrar (X roja `ui_btn_close`); sin arte, `xmark.circle.fill`.
struct ArtCloseButton: View {
    let action: () -> Void
    var size: CGFloat = 40
    var body: some View {
        Button(action: action) {
            Group {
                if let img = UIArt.image("ui_btn_close") {
                    img.resizable().scaledToFit()
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .resizable().scaledToFit()
                        .foregroundStyle(Color("PaletteInk").opacity(0.4))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Es el botón de cerrar de TODAS las hojas y era el único control
        // interactivo del juego sin identifier: sin él, un test sólo puede
        // cerrarlas deslizando, que es un gesto que falla según la hoja.
        .accessibilityIdentifier("sheet.close")
        .accessibilityLabel(Text("store.close"))
    }
}

/// Fondo de panel para sheets basadas en `List`: el marco 9-slice enmarca toda la
/// hoja sin deformarse (pergamino opaco si el asset todavía no existe).
///
/// La base es **pergamino** (`PaletteParchment`) y no el crema de las tarjetas:
/// con el mismo crema en el fondo y en las `GameCard`, las tarjetas no se
/// despegaban del panel (medido contra las referencias del rediseño v3, donde
/// el interior es un beige más hundido que las tarjetas). El interior de los
/// PNG de marco es transparente (alfa 8–15 en el centro, medido sobre
/// `panel_store@3x`), así que esta capa es la que decide el color de TODAS las
/// hojas. El gradiente pone la luz arriba y hunde apenas el pie del panel —el
/// veladero de la referencia— sin tocar el arte.
struct PanelBackground: View {
    let art: String
    var body: some View {
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
            if let frame = UIArt.nineSlice(art, cap: 0.33) {
                frame
            }
        }
        .ignoresSafeArea()
    }
}

/// Burbuja de diálogo con arte propio 9-slice + texto encima que SIEMPRE entra
/// (padding acorde a la forma + auto-encogido). Cola abajo-izquierda.
struct SpeechBubble: View {
    let text: String
    var art: String = "ui_speech_bubble"
    var width: CGFloat = 340

    var body: some View {
        // La burbuja se dimensiona al texto (alto flexible): así NINGÚN string se
        // recorta. Padding horizontal generoso para despejar el borde 9-slice; la
        // cola vive en el padding inferior.
        Text(verbatim: text)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(Color("PaletteInk"))
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: width - 96)
            .padding(.top, 26)
            .padding(.bottom, 52)
            .padding(.horizontal, 30)
            .frame(minWidth: width, minHeight: 150)
            .background {
                ZStack {
                    // Relleno crema (el arte de la burbuja viene con interior transparente).
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color("PaletteCream"))
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 46, trailing: 16))
                    if let bubble = UIArt.nineSlice(art, cap: 0.14) {
                        bubble
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color("PaletteInk"), lineWidth: 3)
                    }
                }
            }
    }
}

/// Toggle vectorial nativo (cápsula verde ON / gris OFF + perilla). Reemplaza al
/// PNG `ui_toggle_on/off` cuyo interior quedó transparente (rembg) — el estado ON
/// no tenía color y era indistinguible del OFF.
struct GameToggle: View {
    let isOn: Bool
    var width: CGFloat = 64
    var height: CGFloat = 36

    var body: some View {
        Capsule()
            .fill(isOn ? Color("PaletteGreen") : Color.black.opacity(0.18))
            .overlay(
                Capsule().strokeBorder(
                    isOn ? Color("PaletteGreen").deepened() : CardMaterials.lockedBorder,
                    lineWidth: 2.5
                )
            )
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(Color("PaletteInk"), lineWidth: 2.5))
                    .padding(3)
            }
            .frame(width: width, height: height)
            .animation(.snappy(duration: 0.18), value: isOn)
    }
}

/// Banner de título consistente para las hojas de menú: cápsula crema + texto
/// display rounded en ink. Se ubica bajo el ornamento del panel (no encima), así
/// el título SIEMPRE es legible sin chocar con el arte del marco.
struct PanelTitleBanner: View {
    let titleKey: LocalizedStringKey
    var body: some View {
        Text(titleKey)
            .font(.system(.title3, design: .rounded).weight(.heavy))
            .foregroundStyle(Color("PaletteInk"))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            )
    }
}
