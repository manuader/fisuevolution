import EconomyKit
import SpriteKit
import UIKit

/// Un piso visual de la torre. Sólo conserva su fondo: los personajes siguen
/// perteneciendo al campo interactivo del piso visible en `BoardScene`.
@MainActor
final class FloorNode: SKNode {
    let definition: FloorDef

    /// Recorta el fondo AL SLOT DEL PISO.
    ///
    /// El fondo se sobredimensiona un 18% para llenar cualquier pantalla sin
    /// dejar bordes, y va anclado abajo para que el suelo quede donde caminan
    /// los personajes. Eso hace que sobre alto POR ARRIBA: sin recortar, ese
    /// excedente se mete en el slot del piso de al lado y —como todos los
    /// fondos comparten zPosition y el orden entre hermanos lo decide el árbol—
    /// el piso de abajo puede terminar pintando sobre el de arriba.
    private let background = SKCropNode()
    private var renderedSize: CGSize = .zero
    private let loops: LoopsManifest
    private let pool: VideoPlayerPool
    private let packs: ArtPacks
    private var backgroundVideo: LoopingVideoNode?
    private var isBackgroundAnimating = false

    /// Orden determinístico entre pisos vivos: `renderLiveFloorNodes` los agrega
    /// iterando un Set, así que sin esto el orden de dibujo entre hermanos es
    /// arbitrario.
    ///
    /// Toda esta banda tiene que quedar por debajo de `BoardScene.fieldBaseZ`: si
    /// se toca con la de los personajes, el fondo tapa a la multitud. Ver el
    /// comentario de `fieldBaseZ`.
    static func backgroundZ(ordinal: Int) -> CGFloat {
        CGFloat(ordinal) * 0.01
    }

    init(ordinal: Int, definition: FloorDef, loops: LoopsManifest = .main,
         pool: VideoPlayerPool = .shared, packs: ArtPacks = .shared) {
        self.definition = definition
        self.loops = loops
        self.pool = pool
        self.packs = packs
        super.init()
        zPosition = Self.backgroundZ(ordinal: ordinal)
        addChild(background)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FloorNode is never decoded")
    }

    var hasBackgroundVideo: Bool { backgroundVideo?.videoNode != nil }

    /// Sólo el piso visible y asentado anima su fondo; sin entrada en el manifest no hay nada que animar.
    func setBackgroundAnimating(_ animating: Bool) {
        isBackgroundAnimating = animating
        backgroundVideo?.setVisible(animating)
    }

    func render(content: GameContent, size: CGSize) {
        guard renderedSize != size || background.children.isEmpty else { return }
        renderedSize = size
        backgroundVideo?.stop()
        backgroundVideo = nil
        background.removeAllChildren()

        let mask = SKSpriteNode(color: .white, size: size)
        mask.anchorPoint = .zero
        background.maskNode = mask

        if let assetName = content.manifest.backgrounds[definition.background].flatMap({ $0.isEmpty ? nil : $0 }),
           UIImage(named: assetName) != nil {
            let sprite = SKSpriteNode(imageNamed: assetName)
            let textureSize = sprite.texture?.size() ?? CGSize(width: 1024, height: 1024)
            let scale = max(size.width / textureSize.width, size.height / textureSize.height) * 1.18
            sprite.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            // Bajar el fondo hunde su franja plana inferior por debajo del slot.
            // El clamp al sobrante REAL del aspect-fill garantiza que el borde
            // superior nunca se despegue del techo del piso.
            let slack = max(0, sprite.size.height - size.height)
            let offset = min(definition.backgroundOffset * size.height, slack)
            sprite.position = CGPoint(x: size.width / 2, y: -offset)
            sprite.zPosition = -100
            if let texture = sprite.texture, loops.entry(for: .floor(definition.background)) != nil {
                let video = LoopingVideoNode(clip: .floor(definition.background), poster: texture, size: sprite.size,
                                             role: .background, manifest: loops, pool: pool, packs: packs)
                video.position = CGPoint(x: sprite.position.x, y: sprite.position.y + sprite.size.height / 2)
                video.zPosition = sprite.zPosition
                background.addChild(video)
                backgroundVideo = video
                video.setVisible(isBackgroundAnimating)
            } else {
                background.addChild(sprite)
            }
            return
        }

        let colors = fallbackColors[definition.background] ?? (Palette.cream, Palette.yellow)
        let sky = SKSpriteNode(color: colors.sky, size: size)
        sky.anchorPoint = .zero
        sky.zPosition = -100
        background.addChild(sky)

        let ground = SKSpriteNode(color: colors.ground, size: CGSize(width: size.width, height: size.height * 0.62))
        ground.anchorPoint = .zero
        ground.zPosition = -99
        background.addChild(ground)
    }

    private let fallbackColors: [String: (sky: SKColor, ground: SKColor)] = [
        "alley": (SKColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1), SKColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1)),
        "urban": (SKColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1), SKColor(red: 0.72, green: 0.66, blue: 0.55, alpha: 1)),
        "corporate": (SKColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 1), SKColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 1)),
        "luxury": (SKColor(red: 0.45, green: 0.8, blue: 0.85, alpha: 1), SKColor(red: 0.93, green: 0.89, blue: 0.78, alpha: 1)),
        "island": (SKColor(red: 0.4, green: 0.85, blue: 0.95, alpha: 1), SKColor(red: 0.96, green: 0.87, blue: 0.62, alpha: 1)),
        "moon": (SKColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1), SKColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)),
        "mars": (SKColor(red: 0.25, green: 0.1, blue: 0.1, alpha: 1), SKColor(red: 0.75, green: 0.4, blue: 0.25, alpha: 1)),
        "solar": (SKColor(red: 0.06, green: 0.07, blue: 0.2, alpha: 1), SKColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1)),
        "galaxy": (SKColor(red: 0.12, green: 0.05, blue: 0.25, alpha: 1), SKColor(red: 0.4, green: 0.3, blue: 0.6, alpha: 1)),
        "cosmic": (SKColor(red: 0.04, green: 0.02, blue: 0.1, alpha: 1), SKColor(red: 0.3, green: 0.15, blue: 0.45, alpha: 1)),
        "god_realm": (SKColor(red: 1, green: 0.92, blue: 0.7, alpha: 1), SKColor(red: 1, green: 0.97, blue: 0.88, alpha: 1)),
    ]
}
