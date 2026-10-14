import EconomyKit
import SwiftUI

/// Los avisos pasajeros (PLAN-v2 E14 C20): el toast de logros y el aviso de la torre.
/// Salen **arriba**, justo bajo el HUD y entre las dos columnas de las esquinas, entran
/// desde arriba y **no comen toques**: se sigue arrastrando y fusionando con el aviso a la
/// vista. Si salen juntos se apilan: el logro arriba, el aviso de la torre debajo.
///
/// Es un `ViewModifier` porque `RootView.body` está al límite del type-checker. Mide el
/// borde de abajo del HUD con el ancla que el HUD ya publica (`.hudBar`).
struct NoticesLayer: ViewModifier {
    @Environment(GameState.self) private var gameState

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                let hudBottom = anchors[.hudBar].map { proxy[$0].maxY } ?? 0
                let topInset: CGFloat = hudBottom + Tokens.s8 + NoticesLayout.compactDrop(forWidth: proxy.size.width)
                VStack(spacing: Tokens.s4) {
                    // Cada aviso en su propio `ZStack` con su `.animation(value:)`: una
                    // `.transition` sólo corre si la inserción cae en una transacción
                    // animada que abre el PADRE, y así la animación no tiñe nada más.
                    ZStack {
                        if let toast = gameState.achievementToast, gameState.showing == .achievements {
                            AchievementToastView(toast: toast) {
                                gameState.dismissAchievementToast(id: toast.id)
                            }
                        }
                    }
                    .animation(.spring(duration: 0.32), value: gameState.achievementToast?.id)
                    ZStack {
                        if let notice = gameState.towerNotice, gameState.showing == .towerNotice {
                            TowerNoticeView(notice: notice) {
                                gameState.dismissTowerNotice(id: notice.id)
                            }
                        }
                    }
                    .animation(.spring(duration: 0.32), value: gameState.towerNotice?.id)
                }
                .padding(.horizontal, NoticesLayout.sideInset)
                .padding(.top, topInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .allowsHitTesting(false)
        }
    }
}

enum NoticesLayout {
    /// El aire a cada lado: lo que ocupan las columnas de las esquinas (C9) más un respiro,
    /// para que el aviso quede entre las dos y no tape ni un sello ni un boost.
    static let sideInset: CGFloat = SideRailLayout.edgeInset + SideRailLayout.touchWidth + Tokens.s12

    /// Hasta este ancho (el SE mide 375) el aviso entre las dos columnas queda angosto y un chip
    /// ancho de la derecha, el del reloj de un evento, lo pisa (D14).
    static let compactWidth: CGFloat = 375
    /// Cuánto se baja el aviso en una pantalla compacta: debajo de la primera tarjeta de la columna
    /// derecha y de su reloj. Los chips no se achican (decisión del dueño, E14b B3).
    static let compactDropHeight: CGFloat = SideRailLayout.touchWidth + SideRailLayout.seal

    static func compactDrop(forWidth width: CGFloat) -> CGFloat {
        width <= compactWidth ? compactDropHeight : 0
    }

    /// Lo que dura el aviso de la torre a la vista. `--uitest-notices-slow` lo estira ×4: con
    /// la máquina cargada cada consulta de XCUITest tarda más de un segundo y los 2,4 s se
    /// iban antes de la primera (relevo 56).
    static var towerNoticeSeconds: Double {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitest-notices-slow") ? 9.6 : 2.4
        #else
        2.4
        #endif
    }
}

/// La placa de un aviso: tarjeta crema con contorno de la casa, un ícono propio y el texto.
private struct NoticePlaque<Icon: View>: View {
    let identifier: String
    let text: Text
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: Tokens.s8) {
            icon()
            text
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color("PaletteInk"))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Tokens.s12)
        .padding(.vertical, Tokens.s8)
        .background {
            let shape = RoundedRectangle(cornerRadius: CardMaterials.cornerRadius, style: .continuous)
            shape.fill(Color("PaletteCream"))
                .overlay(shape.strokeBorder(Color("PaletteInk"), lineWidth: 3))
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

/// El banner de un logro recién conseguido: la copa y el título del logro.
struct AchievementToastView: View {
    let toast: AchievementToast
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Dispara el pulso de la copa: sube una vez por logro desde el `.task(id:)` que cuenta
    /// los 2,4 s. La cola reusa la vista entre dos logros seguidos, así que el disparo
    /// cuelga del `id` y no de un `onAppear`.
    @State private var pulse = 0

    private var tier: VectorTrophyIcon.Tier {
        VectorTrophyIcon.Tier(rawValue: toast.icon.replacingOccurrences(of: "trophy_", with: "")) ?? .bronze
    }

    var body: some View {
        NoticePlaque(identifier: "ach.toast", text: Text(verbatim: toast.titleText)) {
            GameIcon(artKey: tier.artKey, size: 34) { VectorTrophyIcon(tier: tier) }
                .keyframeAnimator(initialValue: 1.0, trigger: pulse) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.3, duration: 0.2, spring: .bouncy)
                        SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                    }
                }
        }
        .task(id: toast.id) {
            if !reduceMotion { pulse += 1 }
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            dismiss()
        }
        .transition(NoticesLayout.transition(reduceMotion: reduceMotion))
    }
}

/// El aviso de la torre: piso lleno, Corralito, un piso que se habilitó, un premio.
struct TowerNoticeView: View {
    let notice: GameState.TowerNotice
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var messageKey: LocalizedStringKey {
        switch notice.kind {
        case .floorFull: "tower.notice.floor_full"
        case .destinationFloorFull: "tower.notice.destination_full"
        case .hireUnlocked: "tower.notice.hire_unlocked"
        case .spendingFrozen: "tower.notice.spending_frozen"
        case .rewardCompensated(let durationText): "tower.notice.reward_compensated \(durationText)"
        case .rewardGranted(let text): "tower.notice.reward_granted \(text)"
        case .packagesWon(let count): count == 1 ? "tower.notice.package_won" : "tower.notice.packages_won \(count)"
        }
    }

    private var glyph: GameGlyph {
        switch notice.kind {
        case .floorFull, .destinationFloorFull, .spendingFrozen: .lock
        case .hireUnlocked: .check
        case .rewardCompensated: .clock
        case .rewardGranted, .packagesWon: .gift
        }
    }

    var body: some View {
        NoticePlaque(identifier: "tower.notice", text: Text(messageKey)) {
            GameGlyphView(glyph: glyph, size: 30)
        }
        .task(id: notice.id) {
            try? await Task.sleep(for: .seconds(NoticesLayout.towerNoticeSeconds))
            guard !Task.isCancelled else { return }
            dismiss()
        }
        .transition(NoticesLayout.transition(reduceMotion: reduceMotion))
    }
}

extension NoticesLayout {
    /// Entran desde arriba; con Reduce Motion se funden en vez de deslizarse.
    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }
}
