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
    ///
    /// ⚠️ **Arranca leído del manifest del bundle, no vacío.** El splash se dibuja
    /// MIENTRAS corre el bootstrap —es lo que tapa—, o sea antes de `configure`:
    /// con el set vacío `image("logo")` daba `nil` y el logo no se vio nunca,
    /// siempre el wordmark de respaldo. Y como `UIArt` no es observable, que el
    /// bootstrap lo configurara después no redibujaba nada. Leído acá, cualquier
    /// vista lo encuentra en su primer frame, sea cual sea el orden de arranque.
    private static var available: Set<String> = bundledNames()
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

    /// Las claves `ui` del manifest del bundle, leídas sin pasar por
    /// `GameContentLoader`: el splash no puede esperar a que cargue el contenido
    /// entero. Un manifest ilegible da el set vacío —todo cae a su vectorial—, y
    /// el error de verdad lo reporta el bootstrap, que lo valida.
    nonisolated static func bundledNames(in bundle: Bundle = .main) -> Set<String> {
        guard let url = bundle.url(forResource: "assets_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(AssetsManifest.self, from: data)
        else { return [] }
        return Set(manifest.ui.keys)
    }

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

    /// Precalienta un retrato SIN bloquear el hilo principal.
    ///
    /// La primera lectura de un personaje cuesta cientos de ms (la PÁGINA del
    /// atlas se decodifica entera; medidos 320–470 ms en el sim), y hacerla
    /// en línea congela lo que esté animándose: la llegada del cofre la
    /// pagaba justo cuando arrancaba el resorte de entrada, y el overlay
    /// quedaba clavado medio segundo antes de aparecer. `preload` carga la
    /// página en background; el `cgImage()` y el caché quedan en el
    /// MainActor con la página ya en memoria. El completion no captura la
    /// textura (no es `Sendable`): vuelve a buscarla por nombre, que ya está
    /// cacheada por el atlas.
    static func warmCharacterImage(atlas atlasName: String, key: String) {
        let cacheKey = "\(atlasName)/\(key)"
        guard characterCache[cacheKey] == nil,
              let texture = AtlasCache.texture(named: key, inAtlas: atlasName)
        else { return }
        texture.preload {
            Task { @MainActor in
                _ = characterImage(atlas: atlasName, key: key)
            }
        }
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
            // margen transparente o todavía no exista. Desde el v3 el respaldo
            // es la cápsula caramelo de la casa (PillBackground): así el CTA de
            // un popup y el PricePill de una hoja son el mismo botón, con o sin
            // arte encima.
            PillBackground(fill: tint)
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

/// Banner de título consistente para las hojas de menú: cápsula crema con el
/// doble borde de la referencia (marrón afuera, pinstripe adentro) + texto
/// display rounded en ink. Se ubica bajo el ornamento del panel (no encima),
/// así el título SIEMPRE es legible sin chocar con el arte del marco.
///
/// `icon` mete el glifo de la pantalla ADENTRO de la cápsula (Regalos, Pintas
/// — así lo componen las referencias); es decoración, el título ya dice todo,
/// y por eso va tapado de VoiceOver acá y no en cada llamador.
struct PanelTitleBanner: View {
    private let title: Text
    var icon: AnyView?

    init(titleKey: LocalizedStringKey, icon: AnyView? = nil) {
        self.title = Text(titleKey)
        self.icon = icon
    }

    /// Para un título ya resuelto (el nombre de un personaje): pasarlo como
    /// clave buscaría una traducción que no existe (trampa 5).
    init(verbatim title: String, icon: AnyView? = nil) {
        self.title = Text(verbatim: title)
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: Tokens.s8) {
            if let icon {
                icon
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)
            }
            title
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(Color("PaletteInk"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(Color("PaletteCream"))
                .overlay(
                    // El pinstripe interior del doble borde.
                    Capsule()
                        .strokeBorder(Color("PaletteBrown").opacity(0.35), lineWidth: 1.5)
                        .padding(4)
                )
                .overlay(Capsule().strokeBorder(Color("PaletteBrown"), lineWidth: 3))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        )
    }
}
