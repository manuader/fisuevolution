#if DEBUG
import SpriteKit
import SwiftUI

/// La galería del dueño (PLAN-v2 E6): los 8 efectos sobre personajes de verdad,
/// parados sobre el fondo del callejón, a escala de tablero. "Todos" pone una
/// columna por efecto; tocar uno lo muestra grande. Con los draws a la vista:
/// es la medición que pide PLAN-v2.
struct SkinEffectsGalleryView: View {
    @State private var selected: String?
    @State private var animated = true
    @State private var scene = SkinGalleryScene(size: CGSize(width: 390, height: 520))

    var body: some View {
        VStack(spacing: 8) {
            SpriteView(scene: scene, options: [.allowsTransparency], debugOptions: [.showsDrawCount, .showsNodeCount, .showsFPS])
                .frame(height: 520)
                .accessibilityElement()
                .accessibilityIdentifier("gallery.stage")
            ScrollView(.horizontal) {
                HStack {
                    Button("Todos") { show(nil) }
                        .accessibilityIdentifier("gallery.effect.all")
                    ForEach(SkinShaders.ids, id: \.self) { id in
                        Button(id) { show(id) }
                            .buttonStyle(.bordered)
                            .tint(selected == id ? .orange : .gray)
                            .accessibilityIdentifier("gallery.effect.\(id)")
                    }
                }
                .padding(.horizontal)
            }
            Toggle("Animado", isOn: $animated)
                .padding(.horizontal)
                .accessibilityIdentifier("gallery.animated")
                .onChange(of: animated) { _, on in SkinShaders.setAnimated(on) }
        }
        .navigationTitle("Efectos de skin")
        .onDisappear { SkinShaders.setAnimated(SkinShaders.systemWantsMotion) }
    }

    private func show(_ id: String?) {
        selected = id
        scene.show(effect: id)
    }
}

/// El escenario: el fondo del callejón y, por efecto, el tipo base y uno de tier
/// alto, al tamaño del tablero del iPhone 16 Pro.
final class SkinGalleryScene: SKScene {
    private var content: GameContent?
    private let renderer = PlaceholderRenderer()

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        content = try? GameContentLoader.load(from: .main)
        show(effect: nil)
    }

    func show(effect: String?) {
        removeAllChildren()
        guard let content else { return }
        if let key = content.manifest.backgrounds["alley"] {
            let floor = SKSpriteNode(imageNamed: key)
            floor.size = size
            floor.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(floor)
        }
        let effects = effect.map { [$0] } ?? SkinShaders.ids
        let types = [content.tiers.baseType] + Array(content.tiers.concreteTypes.suffix(1))
        let column = size.width / CGFloat(effects.count)
        let side = min(column * 1.6, 220)
        for (x, id) in effects.enumerated() {
            for (y, type) in types.enumerated() {
                guard let texture = renderer.texture(for: type, manifest: content.manifest) else { continue }
                let sprite = SKSpriteNode(texture: texture, size: CGSize(width: side, height: side))
                sprite.position = CGPoint(x: column * (CGFloat(x) + 0.5), y: side * 0.55 + CGFloat(y) * side * 0.95)
                SkinShaders.apply(id, to: sprite, phase: Float(x) * 0.9)
                addChild(sprite)
            }
        }
    }
}
#endif
