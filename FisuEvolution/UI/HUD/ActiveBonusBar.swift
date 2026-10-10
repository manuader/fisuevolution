import EconomyKit
import SwiftUI

/// Los contadores de los bonus temporales que están corriendo: abajo del HUD y
/// pegados a la izquierda, uno por bonus. Los chips de evento llevan la cara de
/// quien lo anunció y son botones: abren el popup del evento.
///
/// El tiempo lo cuenta **esta vista** y no la proyección. `ActiveBonus` lleva
/// `expiresAt` y `totalDuration`, que no cambian mientras el bonus vive, así que
/// `GameState` no publica nada nuevo por el paso del tiempo. Acá alcanza con un
/// solo timer de 1 Hz para toda la barra —el mismo patrón que `EventPopupView`,
/// y uno solo, no uno por chip—; el aro se interpola con un tween lineal de 1 s
/// entre tick y tick, así se ve continuo sin animación de larga duración.
struct ActiveBonusBar: View {
    let bonuses: [ActiveBonus]
    /// Tocar el chip de un evento abre su popup.
    var onEventTap: (String) -> Void = { _ in }

    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Alto del ícono con su aro. El resto de la cápsula se acomoda alrededor.
    private static let iconSide: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(bonuses) { bonus in
                Group {
                    if let eventId = bonus.eventId {
                        Button { onEventTap(eventId) } label: { chip(bonus) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("hud.event.chip.\(eventId)")
                            .accessibilityLabel(Text("hud.event.chip.ax \(eventTitle(eventId))"))
                            .tutorialAnchor(.eventChip)
                    } else {
                        // Es estado, no un control: no puede comerse un toque
                        // destinado al tablero que tiene abajo.
                        chip(bonus)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("hud.bonus.chip")
                            .accessibilityLabel(Text("hud.bonus.active.label"))
                    }
                }
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.32), value: bonuses.map(\.id))
        .onReceive(timer) { now = $0 }
        // ⚠️ Sin identificador en el contenedor. Un `accessibilityIdentifier`
        // sobre un `VStack` que no es elemento de accesibilidad **se propaga y
        // pisa el de sus hijos**: con él, el árbol de AX mostraba un solo
        // elemento llamado `hud.bonuses` y los chips desaparecían del test
        // aunque en pantalla se vieran perfectos. Es la trampa 9a del HANDOFF
        // con otra cara: nunca es el control, siempre es el contenedor.
    }

    private func eventTitle(_ id: String) -> String {
        gameState.content?.events.event(id: id).map { VisitCopy.text($0.titleKey) } ?? id
    }

    private func chip(_ bonus: ActiveBonus) -> some View {
        let remaining = max(0, bonus.expiresAt - now.timeIntervalSince1970)
        let time = Self.timeText(remaining)
        let tint = bonus.polarity.map(Self.tint) ?? Self.tint(bonus.effect)
        return HStack(spacing: 7) {
            icon(bonus, tint: tint, progress: Self.progress(remaining: remaining, total: bonus.totalDuration))
            // El número y el tiempo van SIEMPRE, no sólo el color: un evento
            // suma además su flecha (sube, baja, las dos).
            if let polarity = bonus.polarity {
                Image(systemName: Self.symbol(polarity))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(tint)
            }
            Text(verbatim: bonus.effectText)
                .font(.system(size: 15, design: .rounded).weight(.heavy))
                .foregroundStyle(tint)
            Text(verbatim: time)
                .font(.system(size: 13, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color("PaletteInk").opacity(0.7))
        }
        .padding(.leading, 5)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color("PaletteCream"))
                .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        )
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: "\(bonus.effectText) \(time)"))
    }

    private func icon(_ bonus: ActiveBonus, tint: Color, progress: Double) -> some View {
        ZStack {
            Circle().fill(tint.opacity(0.16))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            glyph(bonus, tint: tint)
        }
        .frame(width: Self.iconSide, height: Self.iconSide)
    }

    @ViewBuilder
    private func glyph(_ bonus: ActiveBonus, tint: Color) -> some View {
        switch bonus.icon {
        case .art(let key):
            if let art = UIArt.image(key) {
                art.resizable().scaledToFit()
                    .frame(width: Self.iconSide * 0.62, height: Self.iconSide * 0.62)
            } else {
                // Un boost sin su arte en el atlas sigue mostrando su contador:
                // el manifest cae a placeholder, no a nada.
                symbol("bolt.fill", tint: tint)
            }
        case .symbol(let name):
            symbol(name, tint: tint)
        case .face(let visitorId):
            VisitorFace(visitorId: visitorId, side: Self.iconSide - 6)
        }
    }

    private func symbol(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(tint)
    }

    /// El color de un evento dice hacia dónde va (y la flecha lo repite).
    static func tint(_ polarity: EventCatalog.Polarity) -> Color {
        switch polarity {
        case .positive: Color("PaletteGreen")
        case .negative: Color("PalettePink")
        case .mixed: Color("PaletteOrange")
        }
    }

    static func symbol(_ polarity: EventCatalog.Polarity) -> String {
        switch polarity {
        case .positive: "arrow.up.circle.fill"
        case .negative: "arrow.down.circle.fill"
        case .mixed: "arrow.up.arrow.down.circle.fill"
        }
    }

    /// Cuánto del aro queda pintado. Sin duración conocida va lleno: un bonus
    /// que corre y no se ve es peor que un aro que no se vacía.
    static func progress(remaining: TimeInterval, total: TimeInterval?) -> Double {
        guard let total, total > 0 else { return 1 }
        return min(1, max(0, remaining / total))
    }

    /// "42s" abajo del minuto, "1:42" arriba. Redondea hacia ARRIBA: con el
    /// truncado, un boost recién activado de 60 s aparece marcando 59 s.
    static func timeText(_ remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        guard seconds >= 60 else { return "\(seconds)s" }
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    /// El color codifica QUÉ potencia, nunca cuánto: el número siempre está al lado.
    static func tint(_ effect: ActiveModifier.Effect) -> Color {
        switch effect {
        case .incomeMultiplier: Color("PaletteGreen")
        case .tapMultiplier: Color("PaletteOrange")
        case .spawnCostMultiplier: Color("PaletteBlue")
        case .spendingFrozen: Color("PalettePink")
        case .passiveMultiplier: Color("PaletteGreen")
        case .eventImmunity: Color("PaletteYellow")
        case .packageRateMultiplier: Color("PaletteBrown")
        case .autoTapPerSecond: Color("PaletteBlue")
        case .freeHire: Color("PaletteBlue")
        }
    }
}
