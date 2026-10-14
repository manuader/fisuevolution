import EconomyKit
import SpriteKit
import SwiftUI
import UIKit

/// El arte real de un momento viral (E14 C23), ya cargado como `UIImage`:
/// `ImageRenderer` no espera a nada asíncrono y un atlas que falta en pleno
/// render dejaría un hueco, así que se precarga antes y lo que no está queda
/// en `nil` (el póster dibuja entonces el retrato vectorial de la casa).
struct ShareArtwork {
    /// El personaje con la skin que tiene puesta.
    var portrait: UIImage?
    /// El tinte de las skins que son un color y no una textura.
    var portraitTint: Color?
    /// El fondo del piso donde vive.
    var background: UIImage?
    var logo: UIImage?

    static let empty = ShareArtwork()
}

@MainActor
enum ShareArt {
    /// El arte que ilustra un momento: el personaje del nuevo, del piso que se
    /// abre (su primer personaje), de la reencarnación (el Fisura) o de Dios,
    /// sobre el fondo de su piso.
    static func artwork(for moment: ShareMoment, in gameState: GameState) -> ShareArtwork {
        guard let content = gameState.content else { return ShareArtwork(logo: UIArt.uiImage("logo")) }
        let type = character(for: moment, content: content)
        let hero = type.flatMap { Self.portrait(of: $0, in: gameState) }
        let home = homeFloor(for: moment, type: type, content: content)
        let background = home.flatMap { backgroundImage(of: $0, content: content) }
        return ShareArtwork(
            portrait: hero?.image,
            portraitTint: hero?.tint,
            background: background,
            logo: UIArt.uiImage("logo")
        )
    }

    /// El personaje que protagoniza el momento.
    static func character(for moment: ShareMoment, content: GameContent) -> CharacterType? {
        switch moment {
        case .newCharacter(let type), .god(let type):
            type
        case .newFloor(let floorID):
            content.floorTable.floors.first { $0.id == floorID }
                .flatMap { floor in content.tiers.concreteTypes.first { $0.tier == floor.firstTier } }
        case .reincarnation:
            content.tiers.baseType
        }
    }

    /// El retrato de un personaje con su skin activa; si el arte de la skin no
    /// existe, el del personaje base.
    static func portrait(of type: CharacterType, in gameState: GameState) -> (image: UIImage, tint: Color?)? {
        guard let content = gameState.content, let asset = content.manifest.characters[type.id] else { return nil }
        let skinID = gameState.activeSkinID(forCharacterType: type.id)
        let treatment = SkinResolver.treatment(for: skinID, characterType: type.id, config: content.skins)
        if case let .texture(key) = treatment {
            let atlas = SkinResolver.atlas(for: skinID, characterType: type.id, config: content.skins) ?? asset.atlas
            if let image = atlasImage(atlas: atlas, key: key) { return (image, nil) }
        }
        guard let base = atlasImage(atlas: asset.atlas, key: asset.key) else { return nil }
        return (base, SkinResolver.swiftUITint(for: treatment))
    }

    private static func atlasImage(atlas: String, key: String) -> UIImage? {
        guard let texture = AtlasCache.texture(named: key, inAtlas: atlas) else { return nil }
        return UIImage(cgImage: texture.cgImage(), scale: 1, orientation: .up)
    }

    private static func homeFloor(for moment: ShareMoment, type: CharacterType?, content: GameContent) -> FloorDef? {
        switch moment {
        case .newFloor(let floorID): content.floorTable.floors.first { $0.id == floorID }
        case .newCharacter, .god: type.flatMap { type in content.floorTable.floors.first { $0.contains(tier: type.tier) } }
        case .reincarnation: content.floorTable.floors.first
        }
    }

    /// El fondo, a la medida del póster (1080×1920 como mucho): el PNG de 2048
    /// decodificado entero pesa de más para lo que se ve.
    private static func backgroundImage(of floor: FloorDef, content: GameContent) -> UIImage? {
        guard let asset = content.manifest.backgrounds[floor.background], !asset.isEmpty,
              let full = UIImage(named: asset) else { return nil }
        return full.preparingThumbnail(of: CGSize(width: 1080, height: 1920)) ?? full
    }
}
