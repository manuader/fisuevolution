import EconomyKit
import SpriteKit

/// El contador "×N" de "Fusionar todo": aparece en el segundo eslabón, late con
/// cada uno y se despide con un pulso grande al cerrar la cadena.
@MainActor
final class MergeAllComboNode: SKNode {
    static let nodeName = "mergeAllCombo"
    static let pulseKey = "mergeAllComboPulse"

    private let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let reduceMotion: Bool

    var text: String? { label.text }

    init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        super.init()
        name = Self.nodeName
        zPosition = 180
        alpha = 0
        shadow.fontSize = 34
        shadow.fontColor = Palette.ink.withAlphaComponent(0.6)
        shadow.position = CGPoint(x: 2, y: -2)
        label.fontSize = 34
        label.fontColor = Palette.cream
        for node in [shadow, label] {
            node.verticalAlignmentMode = .center
            addChild(node)
        }
    }

    required init?(coder aDecoder: NSCoder) { nil }

    static func announcement(merges: Int) -> String {
        String(localized: "merge_all.chain.done \(merges)")
    }

    func show(link: BoardChange.Chain) {
        guard link.index > 0 else {
            alpha = 0
            label.text = nil
            shadow.text = nil
            return
        }
        let counter = "×\(link.index + 1)"
        label.text = counter
        shadow.text = counter
        alpha = 1
        guard !reduceMotion else { return }
        run(.sequence([.scale(to: 1.25, duration: 0.06), .scale(to: 1.0, duration: 0.1)]),
            withKey: Self.pulseKey)
    }

    func finish(completion: @escaping @MainActor () -> Void) {
        guard label.text != nil else {
            removeFromParent()
            completion()
            return
        }
        let leave: SKAction = reduceMotion
            ? .fadeOut(withDuration: 0.2)
            : .group([.scale(to: 1.5, duration: 0.35), .fadeOut(withDuration: 0.35)])
        run(leave) { [weak self] in
            MainActor.assumeIsolated {
                self?.removeFromParent()
                completion()
            }
        }
    }
}
