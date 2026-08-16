import EconomyKit
import SpriteKit
import UIKit

/// A reusable board unit: colored plate (phase color) + sprite (placeholder or real
/// art) + tier label. Instances are pooled — merges create and destroy nodes
/// constantly and per-event allocations are off-limits (60 FPS rule).
final class CharacterNode: SKNode {
    static let nodeName = "character"

    /// Los personajes con arte real se muestran 2.2× el tamaño de la celda
    /// (crecen hacia arriba, con los pies apoyados sobre la sombra).
    static let realArtScale: CGFloat = 2.2

    /// Clave del volteo periódico que corre `BoardScene`. Vive acá porque es del
    /// nodo: el pool lo borra al reciclar y `renderPlacements` lo vuelve a
    /// encargar, sin pasar por el ciclo de vida del paseo.
    static let facingActionKey = "facing"

    private let shadow = SKShapeNode()
    private let plate = SKShapeNode()
    private let sprite = SKSpriteNode()
    private let tierLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    private(set) var typeId: String = ""
    private(set) var cellIndex: Int = -1

    override init() {
        super.init()
        name = Self.nodeName

        shadow.fillColor = SKColor.black.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        addChild(shadow)

        plate.lineWidth = 2
        addChild(plate)

        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(sprite)

        tierLabel.horizontalAlignmentMode = .center
        tierLabel.verticalAlignmentMode = .top
        addChild(tierLabel)

        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .bottom
        addChild(nameLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("CharacterNode is never decoded")
    }

    /// `hasRealArt`: con arte del manifest la figura completa ES el personaje
    /// (sin placa ni nombre, parado en el campo); con placeholder mantiene la
    /// placa de color legible. La sombra elíptica bajo los pies va siempre.
    func configure(
        type: CharacterType,
        texture: SKTexture?,
        cellIndex: Int,
        cellSize: CGFloat,
        skinTint: SKColor? = nil,
        hasRealArt: Bool = false
    ) {
        typeId = type.id
        self.cellIndex = cellIndex

        let plateSize = cellSize * 0.92
        let shadowRect = CGRect(
            x: -plateSize * 0.34,
            y: -plateSize * 0.56,
            width: plateSize * 0.68,
            height: plateSize * 0.18
        )
        shadow.path = CGPath(ellipseIn: shadowRect, transform: nil)

        if hasRealArt {
            plate.isHidden = true
            nameLabel.isHidden = true
            sprite.texture = texture
            sprite.isHidden = texture == nil
            // 30% más grande, creciendo hacia arriba: el borde inferior (los pies)
            // se mantiene sobre la sombra en lugar de atravesar el piso.
            let artSide = plateSize * Self.realArtScale
            sprite.size = CGSize(width: artSide, height: artSide)
            sprite.position = CGPoint(x: 0, y: (artSide - plateSize) / 2)
            sprite.color = skinTint ?? .white
            sprite.colorBlendFactor = skinTint == nil ? 0 : 0.25

            tierLabel.isHidden = false
            setLabel(tierLabel, text: "T\(type.tier)", fontSize: plateSize * 0.14)
            tierLabel.fontColor = Palette.ink
            tierLabel.position = CGPoint(x: 0, y: sprite.position.y + artSide * 0.5 + plateSize * 0.03)
            return
        }

        plate.isHidden = false
        nameLabel.isHidden = false
        plate.path = CGPath(
            roundedRect: CGRect(x: -plateSize / 2, y: -plateSize / 2, width: plateSize, height: plateSize),
            cornerWidth: plateSize * 0.18,
            cornerHeight: plateSize * 0.18,
            transform: nil
        )
        plate.fillColor = Palette.color(for: type.phase)
        plate.strokeColor = skinTint ?? Palette.ink
        plate.lineWidth = skinTint == nil ? 2 : 3
        plate.glowWidth = skinTint == nil ? 0 : 3

        sprite.texture = texture
        sprite.isHidden = texture == nil
        sprite.color = .white
        sprite.colorBlendFactor = 0
        let spriteSide = plateSize * 0.52
        sprite.size = CGSize(width: spriteSide, height: spriteSide)
        sprite.position = CGPoint(x: 0, y: plateSize * 0.04)

        tierLabel.isHidden = false
        setLabel(tierLabel, text: "T\(type.tier)", fontSize: plateSize * 0.2)
        tierLabel.fontColor = Palette.ink
        tierLabel.position = CGPoint(x: 0, y: plateSize * 0.46)

        setLabel(nameLabel, text: type.displayName, fontSize: plateSize * 0.11)
        nameLabel.fontColor = Palette.ink
        nameLabel.position = CGPoint(x: 0, y: -plateSize * 0.46)
    }

    /// Espeja al personaje para que mire hacia donde camina.
    ///
    /// ⚠️ El espejado va en el **sprite**, que es hijo, y NUNCA en el nodo. Los
    /// `SKAction.scale(to:)` del tablero —el rebote del tap, el pop del
    /// candidato, el snap-back del arrastre, el vuelo del ascenso— escriben
    /// `xScale` e `yScale` a la vez sobre el nodo: con el espejado ahí, cada tap
    /// devolvería al personaje a mirar a la derecha de un salto visible. El
    /// sprite tiene `anchorPoint` (0.5, 0.5) y `position.x = 0` en los dos
    /// caminos de `configure`, así que darlo vuelta es geométricamente neutro.
    /// La sombra y las etiquetas no se espejan: una sombra elíptica centrada es
    /// simétrica y un "T3" al revés se lee al revés.
    ///
    /// Se preserva la magnitud —y no se escribe un ±1— porque el signo es lo
    /// único que significa "hacia dónde mira": cualquier escala que el sprite
    /// llegue a tener tiene que sobrevivir al espejado.
    func setFacing(left: Bool) {
        let magnitude = abs(sprite.xScale)
        let target = left ? -magnitude : magnitude
        if sprite.xScale != target { sprite.xScale = target }
    }

    var isFacingLeft: Bool { sprite.xScale < 0 }

    /// Asignar `text` o `fontSize` a un `SKLabelNode` lo marca sucio y obliga a
    /// rehacer el layout de Core Text y a re-subir su textura, aunque el valor
    /// sea idéntico. Como `configure` corre sobre los 10 personajes en cada
    /// relayout, escribir sin comparar era lo más caro del ciclo.
    private func setLabel(_ label: SKLabelNode, text: String, fontSize: CGFloat) {
        if label.text != text { label.text = text }
        if label.fontSize != fontSize { label.fontSize = fontSize }
    }
}

/// Minimal object pool for `CharacterNode` (bible §4.2: reuse nodes, never
/// create/destroy per event).
@MainActor
final class CharacterNodePool {
    private var free: [CharacterNode] = []

    /// Entrega SIEMPRE un nodo en estado visual neutro.
    ///
    /// Limpiar acá, y no en cada efecto, es deliberado: el vuelo del ascenso
    /// termina con `alpha = 0` y `configure` no toca la opacidad, así que un
    /// nodo sucio reutilizado renderiza invisible pero sigue siendo clickeable
    /// —el hit-testing mira posición, no opacidad— y el personaje "existe" sin
    /// verse. El pool es el único punto por el que pasan todos los caminos de
    /// reutilización.
    ///
    /// La limpieza va en `obtain` y no en `recycle` porque el vuelo del ascenso
    /// se recicla a sí mismo DESDE el bloque `.run` de su propia secuencia:
    /// tocarle las acciones ahí sería re-entrante. Acá el nodo ya está
    /// desacoplado del árbol y ninguna acción está evaluándose.
    func obtain() -> CharacterNode {
        guard let node = free.popLast() else { return CharacterNode() }
        node.removeAllActions()
        node.alpha = 1
        node.setScale(1)
        // `setScale(1)` limpia el NODO y no a sus hijos, y el espejado vive en el
        // sprite justamente para que ningún `scale(to:)` lo pise: sin esta línea
        // sobreviviría al reciclado y un personaje recién contratado podría
        // aparecer dado vuelta sin que nada lo haya dado vuelta.
        node.setFacing(left: false)
        node.zRotation = 0
        node.isHidden = false
        return node
    }

    func recycle(_ node: CharacterNode) {
        node.removeFromParent()
        // Reciclar dos veces el mismo nodo lo pondría dos veces en la lista
        // libre, y dos personajes distintos compartirían un solo nodo: uno de
        // los dos desaparece. Barato de prevenir, carísimo de diagnosticar.
        guard !free.contains(where: { $0 === node }) else { return }
        free.append(node)
    }
}

/// Palette lookups backed by the asset catalog Color Sets (single source of the
/// visual identity — see Asset-generation.md §3).
@MainActor
enum Palette {
    static var ink: SKColor { named("PaletteInk", fallback: .darkGray) }
    static var cream: SKColor { named("PaletteCream", fallback: .white) }
    static var yellow: SKColor { named("PaletteYellow", fallback: .yellow) }

    static func color(for phase: GamePhase) -> SKColor {
        switch phase {
        case .earth: named("PaletteOrange", fallback: .orange)
        case .cosmic: named("PaletteBlue", fallback: .blue)
        }
    }

    private static func named(_ name: String, fallback: SKColor) -> SKColor {
        SKColor(named: name) ?? fallback
    }
}
