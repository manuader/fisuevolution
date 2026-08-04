import SpriteKit

/// Caché de `SKTextureAtlas` compartida por toda la app.
///
/// `SKTextureAtlas(named:)` no es un lookup barato: abre el atlas compilado y
/// prepara su índice. Había tres sitios llamándolo repetido —el bucle de
/// specials en cada relayout, el flash de cada ascenso y el retrato de la ficha—
/// cuando en realidad hay un puñado fijo de atlas en todo el juego.
///
/// `SKTextureAtlas` ya cachea internamente las texturas que entrega, así que
/// mantener vivo el atlas es lo que evita recargar sus páginas.
@MainActor
enum AtlasCache {
    private static var atlases: [String: SKTextureAtlas] = [:]

    static func atlas(named name: String) -> SKTextureAtlas {
        if let cached = atlases[name] { return cached }
        let atlas = SKTextureAtlas(named: name)
        atlases[name] = atlas
        return atlas
    }

    /// Una textura ausente en SpriteKit vuelve como un placeholder de 1×1 en vez
    /// de `nil`. Este helper lo convierte en el `nil` que uno espera, para que
    /// los llamadores puedan decidir su fallback.
    static func texture(named key: String, inAtlas name: String) -> SKTexture? {
        let texture = atlas(named: name).textureNamed(key)
        guard texture.size().width > 1, texture.size().height > 1 else { return nil }
        return texture
    }

    /// Sólo para tests: permite empezar de cero sin arrastrar atlas de otra suite.
    static func reset() {
        atlases.removeAll()
    }
}
