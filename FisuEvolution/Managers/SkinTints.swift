import Foundation

/// Qué pintas reusan el clip de su tipo base con un tinte, por la clave `"<tipo>__<pinta>"` de
/// `ArtClips.skinKey`. Una pinta que no está acá es de dibujo propio: queda quieta. Spike: una sola
/// entrada habilitada; para generalizar se agregan las demás pintas recoloreo.
enum SkinTints {
    static let table: [String: ArtTint] = [
        ArtClips.skinKey(type: "cartonero", skin: "oro"): .goldMonochrome,
    ]

    static func tint(type: String, skin: String) -> ArtTint? {
        table[ArtClips.skinKey(type: type, skin: skin)]
    }
}
